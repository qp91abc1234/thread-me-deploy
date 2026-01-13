-- --------------------------------------------------------
-- 主机:                           120.24.190.227
-- 服务器版本:                        8.0.44 - MySQL Community Server - GPL
-- 服务器操作系统:                      Linux
-- HeidiSQL 版本:                  12.6.0.6765
-- --------------------------------------------------------

/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET NAMES utf8 */;
/*!50503 SET NAMES utf8mb4 */;
/*!40103 SET @OLD_TIME_ZONE=@@TIME_ZONE */;
/*!40103 SET TIME_ZONE='+00:00' */;
/*!40014 SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0 */;
/*!40101 SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='NO_AUTO_VALUE_ON_ZERO' */;
/*!40111 SET @OLD_SQL_NOTES=@@SQL_NOTES, SQL_NOTES=0 */;

-- 正在导出表  thread_me_db.ApiPermission 的数据：~33 rows (大约)
INSERT IGNORE INTO `ApiPermission` (`id`, `path`, `method`, `matchType`, `desc`, `createTime`, `updateTime`) VALUES
	(1, '/', 'GET', 'exact', 'GET /', '2026-01-13 13:34:41.368', '2026-01-13 13:34:41.368'),
	(2, '/health', 'GET', 'exact', 'GET /health', '2026-01-13 13:34:41.436', '2026-01-13 13:34:41.436'),
	(3, '/auth/login', 'POST', 'exact', 'POST /auth/login', '2026-01-13 13:34:41.457', '2026-01-13 13:34:41.457'),
	(4, '/auth/github-login', 'GET', 'exact', 'GET /auth/github-login', '2026-01-13 13:34:41.478', '2026-01-13 13:34:41.478'),
	(5, '/auth/github-callback', 'GET', 'exact', 'GET /auth/github-callback', '2026-01-13 13:34:41.506', '2026-01-13 13:34:41.506'),
	(6, '/auth/refresh', 'POST', 'exact', 'POST /auth/refresh', '2026-01-13 13:34:41.525', '2026-01-13 13:34:41.525'),
	(7, '/user/list', 'POST', 'exact', '获取用户列表', '2026-01-13 13:34:41.544', '2026-01-13 13:34:41.544'),
	(8, '/user/:id', 'GET', 'exact', '获取用户详情', '2026-01-13 13:34:41.559', '2026-01-13 13:34:41.559'),
	(9, '/user/:id', 'PUT', 'exact', '更新用户', '2026-01-13 13:34:41.582', '2026-01-13 13:34:41.582'),
	(10, '/user/:id', 'DELETE', 'exact', '删除用户', '2026-01-13 13:34:41.595', '2026-01-13 13:34:41.595'),
	(11, '/user', 'POST', 'exact', '新增用户', '2026-01-13 13:34:41.610', '2026-01-13 13:34:41.610'),
	(12, '/file-upload/uploadFiles', 'POST', 'exact', 'POST /file-upload/uploadFiles', '2026-01-13 13:34:41.627', '2026-01-13 13:34:41.627'),
	(13, '/file-upload/uploadChunk', 'POST', 'exact', 'POST /file-upload/uploadChunk', '2026-01-13 13:34:41.643', '2026-01-13 13:34:41.643'),
	(14, '/file-upload/merge', 'GET', 'exact', 'GET /file-upload/merge', '2026-01-13 13:34:41.659', '2026-01-13 13:34:41.659'),
	(15, '/file-upload/ossInfo', 'GET', 'exact', 'GET /file-upload/ossInfo', '2026-01-13 13:34:41.673', '2026-01-13 13:34:41.673'),
	(16, '/role/list', 'POST', 'exact', '获取角色列表', '2026-01-13 13:34:41.686', '2026-01-13 13:34:41.686'),
	(17, '/role/:id', 'GET', 'exact', '获取角色详情', '2026-01-13 13:34:41.713', '2026-01-13 13:34:41.713'),
	(18, '/role/:id', 'PUT', 'exact', '更新角色', '2026-01-13 13:34:41.724', '2026-01-13 13:34:41.724'),
	(19, '/role/:id', 'DELETE', 'exact', '删除角色', '2026-01-13 13:34:41.737', '2026-01-13 13:34:41.737'),
	(20, '/role', 'POST', 'exact', '新增角色', '2026-01-13 13:34:41.751', '2026-01-13 13:34:41.751'),
	(21, '/role/:id/permissions', 'GET', 'exact', '获取角色权限', '2026-01-13 13:34:41.761', '2026-01-13 13:34:41.761'),
	(22, '/role/:id/permissions', 'POST', 'exact', '分配角色权限', '2026-01-13 13:34:41.777', '2026-01-13 13:34:41.777'),
	(23, '/menu/tree', 'GET', 'exact', '获取菜单树', '2026-01-13 13:34:41.789', '2026-01-13 13:34:41.789'),
	(24, '/menu/:id', 'GET', 'exact', '获取菜单详情', '2026-01-13 13:34:41.809', '2026-01-13 13:34:41.809'),
	(25, '/menu/:id', 'PUT', 'exact', '更新菜单', '2026-01-13 13:34:41.820', '2026-01-13 13:34:41.820'),
	(26, '/menu/:id', 'DELETE', 'exact', '删除菜单', '2026-01-13 13:34:41.836', '2026-01-13 13:34:41.836'),
	(27, '/menu', 'POST', 'exact', '新增菜单', '2026-01-13 13:34:41.858', '2026-01-13 13:34:41.858'),
	(28, '/menu/sort', 'PUT', 'exact', '更新菜单排序', '2026-01-13 13:34:41.871', '2026-01-13 13:34:41.871'),
	(29, '/permission/list', 'GET', 'exact', '获取所有API权限列表', '2026-01-13 13:34:41.882', '2026-01-13 13:34:41.882'),
	(30, '/permission/button/menu/:menuId', 'GET', 'exact', '根据菜单ID获取按钮权限列表', '2026-01-13 13:34:41.893', '2026-01-13 13:34:41.893'),
	(31, '/permission/button', 'POST', 'exact', '创建按钮权限', '2026-01-13 13:34:41.902', '2026-01-13 13:34:41.902'),
	(32, '/permission/button/:id', 'PUT', 'exact', '更新按钮权限', '2026-01-13 13:34:41.915', '2026-01-13 13:34:41.915'),
	(33, '/permission/button/:id', 'DELETE', 'exact', '删除按钮权限', '2026-01-13 13:34:41.926', '2026-01-13 13:34:41.926');

-- 正在导出表  thread_me_db.Button 的数据：~0 rows (大约)

-- 正在导出表  thread_me_db.Menu 的数据：~4 rows (大约)
INSERT IGNORE INTO `Menu` (`id`, `name`, `path`, `icon`, `compPath`, `type`, `sort`, `visible`, `status`, `isSystem`, `createTime`, `updateTime`, `parentId`) VALUES
	(1, '权限管理', 'rbac', 'Lock', '', 0, 0, 1, 1, 1, '2026-01-13 13:34:36.275', '2026-01-13 13:34:36.275', NULL),
	(2, '用户管理', 'user', '', '/src/views/user/user.vue', 1, 0, 1, 1, 1, '2026-01-13 13:34:36.293', '2026-01-13 13:34:36.293', 1),
	(3, '角色管理', 'role', '', '/src/views/role/role.vue', 1, 1, 1, 1, 1, '2026-01-13 13:34:36.309', '2026-01-13 13:34:36.309', 1),
	(4, '菜单管理', 'menu', '', '/src/views/menu/menu.vue', 1, 2, 1, 1, 1, '2026-01-13 13:34:36.326', '2026-01-13 13:34:36.326', 1);

-- 正在导出表  thread_me_db.Role 的数据：~2 rows (大约)
INSERT IGNORE INTO `Role` (`id`, `name`, `status`, `isSystem`, `createTime`, `updateTime`) VALUES
	(1, 'admin', 1, 1, '2026-01-13 13:34:36.069', '2026-01-13 13:34:36.069'),
	(2, 'general_user', 1, 0, '2026-01-13 13:34:36.159', '2026-01-13 13:34:36.159');

-- 正在导出表  thread_me_db.User 的数据：~1 rows (大约)
INSERT IGNORE INTO `User` (`id`, `username`, `password`, `realName`, `email`, `phone`, `status`, `isSystem`, `createTime`, `updateTime`) VALUES
	(1, 'admin', '$2b$10$xqTCdcgy2vRDgD9h4BwTXOCkWKbzMzuaqFo4y70hZT6xt0AXbPuJe', '管理员', '', '', 1, 1, '2026-01-13 13:34:36.254', '2026-01-13 13:34:36.254');

-- 正在导出表  thread_me_db._ApiPermissionToRole 的数据：~33 rows (大约)
INSERT IGNORE INTO `_ApiPermissionToRole` (`A`, `B`) VALUES
	(1, 1),
	(2, 1),
	(3, 1),
	(4, 1),
	(5, 1),
	(6, 1),
	(7, 1),
	(8, 1),
	(9, 1),
	(10, 1),
	(11, 1),
	(12, 1),
	(13, 1),
	(14, 1),
	(15, 1),
	(16, 1),
	(17, 1),
	(18, 1),
	(19, 1),
	(20, 1),
	(21, 1),
	(22, 1),
	(23, 1),
	(24, 1),
	(25, 1),
	(26, 1),
	(27, 1),
	(28, 1),
	(29, 1),
	(30, 1),
	(31, 1),
	(32, 1),
	(33, 1);

-- 正在导出表  thread_me_db._MenuToRole 的数据：~4 rows (大约)
INSERT IGNORE INTO `_MenuToRole` (`A`, `B`) VALUES
	(1, 1),
	(2, 1),
	(3, 1),
	(4, 1);

-- 正在导出表  thread_me_db._RoleToUser 的数据：~1 rows (大约)
INSERT IGNORE INTO `_RoleToUser` (`A`, `B`) VALUES
	(1, 1);

/*!40103 SET TIME_ZONE=IFNULL(@OLD_TIME_ZONE, 'system') */;
/*!40101 SET SQL_MODE=IFNULL(@OLD_SQL_MODE, '') */;
/*!40014 SET FOREIGN_KEY_CHECKS=IFNULL(@OLD_FOREIGN_KEY_CHECKS, 1) */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40111 SET SQL_NOTES=IFNULL(@OLD_SQL_NOTES, 1) */;
