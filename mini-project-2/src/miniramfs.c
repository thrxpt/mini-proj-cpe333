// SPDX-License-Identifier: GPL-2.0
/*
 * miniramfs - Mini RAM-Based File System (CPE333 Mini-Project 2)
 *
 * Target kernel : 6.8.x (Ubuntu 24.04 series, e.g. 6.8.12-fuse2005)
 * Supports      : mount, umount, create file, read, write,
 *                 mkdir, list directory (+ unlink/rmdir/truncate as bonus)
 *
 * Design (modelled on fs/ramfs/inode.c):
 *  - Every inode lives only in RAM (new_inode()).
 *  - Dentries are pinned with dget() so files survive while mounted;
 *    kill_litter_super() drops them on umount -> inodes are evicted.
 *  - File data is a kmalloc'ed buffer (struct miniramfs_file_data) stored
 *    in inode->i_private, grown with krealloc() and freed in evict_inode().
 *  - Invariant: every byte of the buffer beyond i_size is zero, so sparse
 *    writes and truncate-then-grow never leak stale data.
 *
 * NOTE: inode_operations signatures changed between kernel versions.
 *       Verify against include/linux/fs.h of the kernel you build with.
 */
#include <linux/module.h>
#include <linux/fs.h>
#include <linux/pagemap.h>
#include <linux/slab.h>
#include <linux/uaccess.h>
#include <linux/statfs.h>
#include <linux/mount.h>
#include <linux/string.h>

#define MINIRAMFS_MAGIC		0x4D52464Cu	/* "MRFL" */
#define MINIRAMFS_MAX_FILE	(1UL << 20)	/* 1 MiB per file (kmalloc-friendly) */
#define MINIRAMFS_MIN_ALLOC	64UL

struct miniramfs_file_data {
	char   *data;		/* file contents in kernel RAM */
	size_t  capacity;	/* allocated bytes */
};

static const struct super_operations miniramfs_sops;
static const struct inode_operations miniramfs_dir_iops;
static const struct inode_operations miniramfs_file_iops;
static const struct file_operations  miniramfs_file_fops;

/* ------------------------------------------------------------------ */
/* Buffer management                                                   */
/* ------------------------------------------------------------------ */

/* Make sure the buffer can hold at least @need bytes. Caller holds inode lock. */
static int miniramfs_reserve(struct miniramfs_file_data *fd, size_t need)
{
	size_t newcap;
	char *p;

	if (need <= fd->capacity)
		return 0;
	if (need > MINIRAMFS_MAX_FILE)
		return -EFBIG;

	newcap = max(MINIRAMFS_MIN_ALLOC, fd->capacity);
	while (newcap < need)
		newcap *= 2;
	if (newcap > MINIRAMFS_MAX_FILE)
		newcap = MINIRAMFS_MAX_FILE;

	p = krealloc(fd->data, newcap, GFP_KERNEL);
	if (!p)
		return -ENOMEM;
	memset(p + fd->capacity, 0, newcap - fd->capacity);	/* keep zero invariant */
	fd->data = p;
	fd->capacity = newcap;
	return 0;
}

/* Set file size (truncate / extend). Caller holds inode lock. */
static int miniramfs_resize(struct inode *inode, loff_t newsize)
{
	struct miniramfs_file_data *fd = inode->i_private;
	loff_t oldsize = i_size_read(inode);
	int ret;

	if (newsize < 0)
		return -EINVAL;
	if (newsize > oldsize) {
		ret = miniramfs_reserve(fd, newsize);
		if (ret)
			return ret;
	} else if (newsize < oldsize) {
		memset(fd->data + newsize, 0, oldsize - newsize);
	}
	i_size_write(inode, newsize);
	return 0;
}

/* ------------------------------------------------------------------ */
/* File operations: read / write                                       */
/* ------------------------------------------------------------------ */

static ssize_t miniramfs_read(struct file *file, char __user *buf,
			      size_t len, loff_t *ppos)
{
	struct inode *inode = file_inode(file);
	struct miniramfs_file_data *fd = inode->i_private;
	loff_t pos = *ppos;
	loff_t size;
	ssize_t ret;

	inode_lock_shared(inode);
	size = i_size_read(inode);
	if (pos < 0) {
		ret = -EINVAL;
		goto out;
	}
	if (pos >= size || len == 0) {		/* EOF or empty file */
		ret = 0;
		goto out;
	}
	if (len > size - pos)
		len = size - pos;

	if (copy_to_user(buf, fd->data + pos, len)) {	/* never touch user ptr directly */
		ret = -EFAULT;
		goto out;
	}
	*ppos = pos + len;
	ret = len;
out:
	inode_unlock_shared(inode);
	return ret;
}

static ssize_t miniramfs_write(struct file *file, const char __user *buf,
			       size_t len, loff_t *ppos)
{
	struct inode *inode = file_inode(file);
	struct miniramfs_file_data *fd = inode->i_private;
	loff_t pos;
	ssize_t ret;

	if (len == 0)
		return 0;

	inode_lock(inode);
	pos = (file->f_flags & O_APPEND) ? i_size_read(inode) : *ppos;
	if (pos < 0 || len > MINIRAMFS_MAX_FILE ||
	    pos > (loff_t)MINIRAMFS_MAX_FILE - (loff_t)len) {
		ret = -EFBIG;
		goto out;
	}

	ret = miniramfs_reserve(fd, pos + len);
	if (ret)
		goto out;

	if (copy_from_user(fd->data + pos, buf, len)) {
		ret = -EFAULT;
		goto out;
	}

	pos += len;
	*ppos = pos;
	if (pos > i_size_read(inode))
		i_size_write(inode, pos);
	inode_set_mtime_to_ts(inode, inode_set_ctime_current(inode));
	ret = len;
out:
	inode_unlock(inode);
	return ret;
}

static const struct file_operations miniramfs_file_fops = {
	.open	= generic_file_open,
	.read	= miniramfs_read,
	.write	= miniramfs_write,
	.llseek	= generic_file_llseek,
};

/* `echo x > file` opens with O_TRUNC -> setattr(ATTR_SIZE) */
static int miniramfs_setattr(struct mnt_idmap *idmap, struct dentry *dentry,
			     struct iattr *attr)
{
	struct inode *inode = d_inode(dentry);
	int ret;

	ret = setattr_prepare(idmap, dentry, attr);
	if (ret)
		return ret;
	if (attr->ia_valid & ATTR_SIZE) {
		/* notify_change() callers (do_truncate) already hold i_rwsem */
		ret = miniramfs_resize(inode, attr->ia_size);
		if (ret)
			return ret;
	}
	setattr_copy(idmap, inode, attr);
	mark_inode_dirty(inode);
	return 0;
}

static const struct inode_operations miniramfs_file_iops = {
	.setattr = miniramfs_setattr,
	.getattr = simple_getattr,
};

/* ------------------------------------------------------------------ */
/* Inode creation + directory operations: create / mkdir               */
/* ------------------------------------------------------------------ */

static struct inode *miniramfs_get_inode(struct super_block *sb,
					 const struct inode *dir, umode_t mode)
{
	struct inode *inode = new_inode(sb);

	if (!inode)
		return NULL;

	inode->i_ino = get_next_ino();
	inode_init_owner(&nop_mnt_idmap, inode, dir, mode);
	simple_inode_init_ts(inode);

	switch (mode & S_IFMT) {
	case S_IFREG: {
		struct miniramfs_file_data *fd = kzalloc(sizeof(*fd), GFP_KERNEL);

		if (!fd) {
			iput(inode);
			return NULL;
		}
		inode->i_private = fd;
		inode->i_op  = &miniramfs_file_iops;
		inode->i_fop = &miniramfs_file_fops;
		break;
	}
	case S_IFDIR:
		inode->i_op  = &miniramfs_dir_iops;
		inode->i_fop = &simple_dir_operations;	/* gives us `ls` with . and .. */
		inc_nlink(inode);			/* "." */
		break;
	default:
		iput(inode);
		return NULL;
	}
	return inode;
}

static int miniramfs_mknod(struct mnt_idmap *idmap, struct inode *dir,
			   struct dentry *dentry, umode_t mode)
{
	struct inode *inode = miniramfs_get_inode(dir->i_sb, dir, mode);

	if (!inode)
		return -ENOSPC;

	d_instantiate(dentry, inode);
	dget(dentry);	/* pin dentry in RAM, otherwise the file vanishes (as in ramfs) */
	inode_set_mtime_to_ts(dir, inode_set_ctime_current(dir));
	return 0;
}

static int miniramfs_create(struct mnt_idmap *idmap, struct inode *dir,
			    struct dentry *dentry, umode_t mode, bool excl)
{
	return miniramfs_mknod(idmap, dir, dentry, mode | S_IFREG);
}

static int miniramfs_mkdir(struct mnt_idmap *idmap, struct inode *dir,
			   struct dentry *dentry, umode_t mode)
{
	int ret = miniramfs_mknod(idmap, dir, dentry, mode | S_IFDIR);

	if (!ret)
		inc_nlink(dir);		/* ".." of the new directory */
	return ret;
}

static const struct inode_operations miniramfs_dir_iops = {
	.create		= miniramfs_create,
	.lookup		= simple_lookup,
	.link		= simple_link,
	.unlink		= simple_unlink,
	.mkdir		= miniramfs_mkdir,
	.rmdir		= simple_rmdir,
	.rename		= simple_rename,
};

/* ------------------------------------------------------------------ */
/* Super block: free file buffers when an inode is evicted             */
/* ------------------------------------------------------------------ */

static void miniramfs_evict_inode(struct inode *inode)
{
	struct miniramfs_file_data *fd = inode->i_private;

	truncate_inode_pages_final(&inode->i_data);
	clear_inode(inode);
	if (fd) {			/* prevents memory leak on unlink / umount */
		kfree(fd->data);
		kfree(fd);
		inode->i_private = NULL;
	}
}

static const struct super_operations miniramfs_sops = {
	.statfs		= simple_statfs,
	.drop_inode	= generic_delete_inode,
	.evict_inode	= miniramfs_evict_inode,
};

static int miniramfs_fill_super(struct super_block *sb, void *data, int silent)
{
	struct inode *root;

	sb->s_maxbytes		= MINIRAMFS_MAX_FILE;
	sb->s_blocksize		= PAGE_SIZE;
	sb->s_blocksize_bits	= PAGE_SHIFT;
	sb->s_magic		= MINIRAMFS_MAGIC;
	sb->s_op		= &miniramfs_sops;
	sb->s_time_gran		= 1;

	root = miniramfs_get_inode(sb, NULL, S_IFDIR | 0755);
	if (!root)
		return -ENOMEM;
	sb->s_root = d_make_root(root);
	if (!sb->s_root)
		return -ENOMEM;
	pr_info("miniramfs: mounted\n");
	return 0;
}

static struct dentry *miniramfs_mount(struct file_system_type *fs_type,
				      int flags, const char *dev_name, void *data)
{
	return mount_nodev(fs_type, flags, data, miniramfs_fill_super);
}

static void miniramfs_kill_sb(struct super_block *sb)
{
	kill_litter_super(sb);	/* drops pinned dentries -> evict_inode frees data */
	pr_info("miniramfs: unmounted\n");
}

static struct file_system_type miniramfs_fs_type = {
	.owner		= THIS_MODULE,
	.name		= "miniramfs",
	.mount		= miniramfs_mount,
	.kill_sb	= miniramfs_kill_sb,
};

static int __init miniramfs_init(void)
{
	int ret = register_filesystem(&miniramfs_fs_type);

	if (ret)
		pr_err("miniramfs: register_filesystem failed (%d)\n", ret);
	else
		pr_info("miniramfs: module loaded\n");
	return ret;
}

static void __exit miniramfs_exit(void)
{
	unregister_filesystem(&miniramfs_fs_type);
	pr_info("miniramfs: module unloaded\n");
}

module_init(miniramfs_init);
module_exit(miniramfs_exit);

MODULE_LICENSE("GPL");
MODULE_AUTHOR("CPE333 Mini-Project 2 team");
MODULE_DESCRIPTION("Mini RAM-based file system on Linux VFS");
