package db

import (
	"errors"
	"log"
	"myfileserver/lib"
	"time"
)

type UserEntry struct {
	Id           int64  `json:"id"`
	Name         string `json:"name"`           // 用户名
	Password     string `json:"password"`       // 密码
	Email        string `json:"email"`          // 邮箱Email
	Enabled      bool   `json:"enabled"`        // 是否启用
	CreatedAt    string `json:"created_at"`     // 创建时间
	UpdatedAt    string `json:"updated_at"`     // 更新时间
	LastLoginAt  string `json:"last_login_at"`  // 最后一次登录时间
	RootDir      string `json:"root_dir"`       // 用户的根目录
	IsAdmin      bool   `json:"is_admin"`       // 是否是管理员
	ShowDotFiles bool   `json:"show_dot_files"` // 是否显示隐藏文件
}

type UserHistoryEntry struct {
	Id          int64  `json:"id"`
	UserId      int64  `json:"user_id"`
	UserName    string `json:"user_name"`
	Action      string `json:"action"`      // 操作类型
	Information string `json:"information"` // 操作信息
	Ip          string `json:"ip"`          // 操作的 IP
	CreatedAt   string `json:"created_at"`  // 创建时间
}

type UserSettingEntry struct {
	Id     int64  `json:"id"`
	UserId int64  `json:"user_id"`
	Key    string `json:"key"`
	Value  string `json:"value"`
}

func (database *Database) InitUser() error {
	// 创建 用户 表，用于存储用户的信息
	_, err := database.db.Exec(`
		CREATE TABLE IF NOT EXISTS User (
			id INTEGER PRIMARY KEY AUTOINCREMENT,
			name TEXT NOT NULL,
			password TEXT NOT NULL,
			email TEXT NOT NULL,
			enabled INTEGER NOT NULL,
			created_at TEXT NOT NULL,
			updated_at TEXT NOT NULL,
			last_login_at TEXT,
			root_dir Text NOT NULL,
			is_admin INTEGER NOT NULL,
			show_dot_files INTEGER NOT NULL
		);
	`)
	if err != nil {
		log.Fatalln(err)
		return err
	}

	// 创建 UserHistory 表，用于记录共享文件的历史操作
	_, err = database.db.Exec(`
		CREATE TABLE IF NOT EXISTS UserHistory (
			id INTEGER PRIMARY KEY AUTOINCREMENT,
			user_id INTEGER NOT NULL,
			user_name TEXT NOT NULL,
			information TEXT NOT NULL,
			action TEXT NOT NULL,
			ip TEXT NOT NULL,
			created_at TEXT NOT NULL
		);
	`)
	if err != nil {
		lib.Logger.Error(err)
		return err
	}
	ret := 0
	err = database.db.QueryRow(`SELECT 1 FROM sqlite_master WHERE type='table' AND name=? AND sql LIKE ?;`,
		"UserHistory", "%user_name%").Scan(&ret)
	if err != nil {
		lib.Logger.Info("user_name not in UserHistory, add it")
		_, err = database.db.Exec(`
			ALTER TABLE UserHistory ADD COLUMN user_name TEXT NOT NULL DEFAULT '';
		`)
		if err != nil {
			lib.Logger.Error(err)
			return err
		}
	}

	// 创建 UserSetting 表，用于记录用户的配置信息
	_, err = database.db.Exec(`
		CREATE TABLE IF NOT EXISTS UserSetting (
			id INTEGER PRIMARY KEY AUTOINCREMENT,
			user_id INTEGER NOT NULL,
			key TEXT NOT NULL,
			value TEXT NOT NULL
		);
	`)
	if err != nil {
		lib.Logger.Error(err)
		return err
	}
	return nil
}

func (database *Database) GetUser(name string) (UserEntry, error) {
	user := UserEntry{}
	err := database.db.QueryRow(`
		SELECT id, name, password, email, enabled, created_at, updated_at, last_login_at, root_dir, is_admin, show_dot_files
		FROM User
		WHERE name =?;
	`, name).Scan(
		&user.Id,
		&user.Name,
		&user.Password,
		&user.Email,
		&user.Enabled,
		&user.CreatedAt,
		&user.UpdatedAt,
		&user.LastLoginAt,
		&user.RootDir,
		&user.IsAdmin,
		&user.ShowDotFiles)
	if err != nil {
		lib.Logger.Error("GetUser failed!", err)
		return UserEntry{}, err
	}
	return user, nil
}

func (database *Database) GetUserById(id int64) (UserEntry, error) {
	user := UserEntry{}
	err := database.db.QueryRow(`
		SELECT id, name, password, email, enabled, created_at, updated_at, last_login_at, root_dir, is_admin, show_dot_files
		FROM User
		WHERE id =?;
	`, id).Scan(
		&user.Id,
		&user.Name,
		&user.Password,
		&user.Email,
		&user.Enabled,
		&user.CreatedAt,
		&user.UpdatedAt,
		&user.LastLoginAt,
		&user.RootDir,
		&user.IsAdmin,
		&user.ShowDotFiles)
	if err != nil {
		lib.Logger.Error("GetUserById id =", id, err)
		return user, err
	}

	return user, nil
}

func (database *Database) GetUsers() ([]UserEntry, error) {
	users := []UserEntry{}
	rows, err := database.db.Query(`
		SELECT id, name, password, email, enabled, created_at, updated_at, last_login_at, root_dir, is_admin, show_dot_files
		FROM User;
	`)
	if err != nil {
		lib.Logger.Error("GetUsers", err)
		return users, err
	}
	defer rows.Close()
	for rows.Next() {
		var user UserEntry
		err := rows.Scan(
			&user.Id,
			&user.Name,
			&user.Password,
			&user.Email,
			&user.Enabled,
			&user.CreatedAt,
			&user.UpdatedAt,
			&user.LastLoginAt,
			&user.RootDir,
			&user.IsAdmin,
			&user.ShowDotFiles)
		if err != nil {
			lib.Logger.Error("GetUsers", err)
			return users, err
		}
		users = append(users, user)
	}
	return users, nil
}

func (database *Database) AddUser(user UserEntry) error {
	_, err := database.db.Exec(`
		INSERT INTO User (name, password, email, enabled, created_at, updated_at, last_login_at, root_dir, is_admin, show_dot_files)
		VALUES (?,?,?,?,?,?,?,?,?,?);
	`,
		user.Name,
		user.Password,
		user.Email,
		user.Enabled,
		time.Now().Format(time.DateTime),
		time.Now().Format(time.DateTime),
		user.LastLoginAt,
		user.RootDir,
		user.IsAdmin,
		user.ShowDotFiles)
	if err != nil {
		lib.Logger.Error("AddUser", err)
		return err
	}
	return nil
}

func (database *Database) UpdateUserLastLoginAt(user UserEntry) error {
	_, err := database.db.Exec(`
		UPDATE User
		SET last_login_at=?
		WHERE id=?;
	`,
		user.LastLoginAt,
		user.Id)
	if err != nil {
		lib.Logger.Error("UpdateUserLastLoginAt", err)
		return err
	}
	return nil
}

func (database *Database) UpdateUser(user UserEntry) error {
	if user.Password == "" {
		return errors.New("password is empty")
	}
	_, err := database.db.Exec(`
		UPDATE User
		SET name=?, email=?, enabled=?, password=?, root_dir=?, is_admin=?, show_dot_files=?, updated_at=?
		WHERE id=?;
	`,
		user.Name,
		user.Email,
		user.Enabled,
		user.Password,
		user.RootDir,
		user.IsAdmin,
		user.ShowDotFiles,
		time.Now().Format(time.DateTime),
		user.Id)
	if err != nil {
		lib.Logger.Error("UpdateUser", err)
		return err
	}
	return nil
}

func (database *Database) DeleteUser(id int64) error {
	_, err := database.db.Exec(`
		DELETE FROM User
		WHERE id =?;
	`, id)
	if err != nil {
		lib.Logger.Error("DeleteUser", err)
		return err
	}
	return nil
}

func (database *Database) AddUserHistory(entry UserHistoryEntry) error {
	_, err := database.db.Exec(`
		INSERT INTO UserHistory (user_id, user_name, information, action, ip, created_at)
		VALUES (?,?,?,?,?,?);
	`,
		entry.UserId,
		entry.UserName,
		entry.Information,
		entry.Action,
		entry.Ip,
		time.Now().Format(time.DateTime))
	if err != nil {
		lib.Logger.Error("AddUserHistory", err)
		return err
	}
	return nil
}

func (database *Database) GetUserHistory(userId int64) ([]UserHistoryEntry, error) {
	history := []UserHistoryEntry{}
	rows, err := database.db.Query(`
		SELECT id, user_id, user_name, information, action, ip, created_at
		FROM UserHistory 
		WHERE user_id =? 
		ORDER BY id DESC;
	`, userId)
	if err != nil {
		lib.Logger.Error("GetUserHistory", err)
		return history, err
	}
	defer rows.Close()
	for rows.Next() {
		var entry UserHistoryEntry
		err := rows.Scan(
			&entry.Id,
			&entry.UserId,
			&entry.UserName,
			&entry.Information,
			&entry.Action,
			&entry.Ip,
			&entry.CreatedAt)
		if err != nil {
			lib.Logger.Error("GetUserHistory", err)
			return history, err
		}
		history = append(history, entry)
	}
	return history, nil
}

func (database *Database) GetUserSetting(userId int64, key string) (UserSettingEntry, error) {
	entry := UserSettingEntry{}
	err := database.db.QueryRow(`
		SELECT id, user_id, key, value
		FROM UserSetting
		WHERE user_id =? and key =?;
	`, userId, key).Scan(
		&entry.Id,
		&entry.UserId,
		&entry.Key,
		&entry.Value)
	if err != nil {
		lib.Logger.Error("GetUserSetting failed! err:", err, " userId:", userId, " key:", key)
		return entry, err
	}
	return entry, nil
}

func (database *Database) IsExistUserSetting(userId int64, key string) bool {
	rows, err := database.db.Query(`
		SELECT COUNT(*)
		FROM UserSetting
		WHERE user_id =? and key =?;
	`, userId, key)
	if err != nil {
		lib.Logger.Error(err)
		return false
	}
	defer rows.Close()
	rows.Next()
	count := 0
	err = rows.Scan(&count)
	if err != nil {
		lib.Logger.Error("GetUserSetting", err)
		return false
	}
	return count > 0
}

func (database *Database) SetUserSetting(userId int64, key string, value string) error {
	// 先判断是否存在

	exist := database.IsExistUserSetting(userId, key)
	if !exist {
		// 不存在则插入
		_, err := database.db.Exec(`
			INSERT INTO UserSetting (user_id, key, value)
			VALUES (?, ?, ?);
		`, userId, key, value)
		if err != nil {
			lib.Logger.Error("SetUserSetting", err)
			return err
		}
		return nil
	}

	// 存在则更新
	_, err := database.db.Exec(`
		UPDATE UserSetting
		SET value=?
		WHERE (user_id =? and key =?);
	`,
		value,
		userId,
		key)
	if err != nil {
		lib.Logger.Error("SetUserSetting", err)
		return err
	}
	return nil
}

func (database *Database) GetUserSettings(userId int64) ([]UserSettingEntry, error) {
	settings := []UserSettingEntry{}
	rows, err := database.db.Query(`
		SELECT id, user_id, key, value
		FROM UserSetting
		WHERE user_id =?;
	`, userId)
	if err != nil {
		lib.Logger.Error("GetUserSettings", err)
		return settings, err
	}
	defer rows.Close()
	for rows.Next() {
		var entry UserSettingEntry
		err := rows.Scan(
			&entry.Id,
			&entry.UserId,
			&entry.Key,
			&entry.Value)
		if err != nil {
			lib.Logger.Error("GetUserSettings", err)
			return settings, err
		}
		settings = append(settings, entry)
	}
	return settings, nil
}
