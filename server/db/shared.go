package db

import (
	"myfileserver/lib"
	"time"
)

type SharedEntry struct {
	Name              string `json:"name"`                // 分享名称
	UserId            int64  `json:"user_id"`             // 用户ID
	Sid               string `json:"sid"`                 // 分享码ID
	Code              string `json:"code"`                // 分享码
	Path              string `json:"path"`                // 目录或文件的路径
	CanDownload       bool   `json:"can_download"`        // 是否允许下载
	CanUpload         bool   `json:"can_upload"`          // 是否允许上传
	MaxCount          int    `json:"max_count"`           // 限制最大下载次数
	MaxUploadSize     int64  `json:"max_upload_size"`     // 限制最大大小，单位：字节
	TimeLimied        int32  `json:"time_limited"`        // 限时，单位：天
	CurrentCount      int    `json:"current_count"`       // 当前下载次数
	CurrentUploadSize int64  `json:"current_upload_size"` // 当前大小，单位：字节
	CreatedAt         string `json:"created_at"`          // 创建时间
}

type SharedHistoryEntry struct {
	Id          int64  `json:"id"`
	Sid         string `json:"sid"`
	Information string `json:"information"` // 操作信息
	Action      string `json:"action"`      // 操作类型
	Ip          string `json:"ip"`          // 操作的 IP
	CreatedAt   string `json:"created_at"`  // 创建时间
}

func (database *Database) InitShared() error {
	// 创建 Shared 表，用于存储共享文件的信息
	_, err := database.db.Exec(`
		CREATE TABLE IF NOT EXISTS Shared (
			sid TEXT PRIMARY KEY,
			name TEXT NOT NULL,
			code TEXT NOT NULL,
			path TEXT NOT NULL,
			can_download INTEGER NOT NULL,
			can_upload INTEGER NOT NULL,
			current_count INTEGER NOT NULL,
			max_count INTEGER NOT NULL,
			current_upload_size INTEGER NOT NULL,
			max_upload_size INTEGER NOT NULL,
			time_limit INTEGER NOT NULL,
			created_at TEXT NOT NULL,
			user_id INTEGER NOT NULL
		);
	`)
	if err != nil {
		lib.Logger.Error("InitShared", err)
		return err
	}

	// 创建 SharedHistory 表，用于记录共享文件的历史操作
	_, err = database.db.Exec(`
		CREATE TABLE IF NOT EXISTS SharedHistory (
			id INTEGER PRIMARY KEY AUTOINCREMENT,
			sid TEXT NOT NULL,
			information TEXT NOT NULL,
			action TEXT NOT NULL,
			ip TEXT NOT NULL,
			created_at TEXT NOT NULL
		);
	`)
	if err != nil {
		lib.Logger.Error("InitShared", err)
		return err
	}
	return nil
}

func (database *Database) CreateShared(shared SharedEntry) error {
	_, err := database.db.Exec(`
		INSERT INTO Shared (sid, user_id, name, code, path, can_download, can_upload, current_count, max_count, current_upload_size, max_upload_size, time_limit, created_at)
		VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?);
	`,
		shared.Sid,
		shared.UserId,
		shared.Name,
		shared.Code,
		shared.Path,
		shared.CanDownload,
		shared.CanUpload,
		shared.CurrentCount,
		shared.MaxCount,
		shared.CurrentUploadSize,
		shared.MaxUploadSize,
		shared.TimeLimied,
		time.Now().Format(time.DateTime))
	if err != nil {
		lib.Logger.Error("InsertShared", err)
		return err
	}
	return nil
}

func (database *Database) GetSharedList(user_id int64) ([]SharedEntry, error) {
	shareds := []SharedEntry{}
	rows, err := database.db.Query(`
		SELECT sid, user_id, name, code, path, can_download, can_upload, current_count, max_count, current_upload_size, max_upload_size, time_limit, created_at
		FROM Shared
		WHERE user_id =?;
	`, user_id)
	if err != nil {
		lib.Logger.Error("GetSharedList", err)
		return shareds, err
	}
	defer rows.Close()
	for rows.Next() {
		shared := SharedEntry{}
		err := rows.Scan(
			&shared.Sid,
			&shared.UserId,
			&shared.Name,
			&shared.Code,
			&shared.Path,
			&shared.CanDownload,
			&shared.CanUpload,
			&shared.CurrentCount,
			&shared.MaxCount,
			&shared.CurrentUploadSize,
			&shared.MaxUploadSize,
			&shared.TimeLimied,
			&shared.CreatedAt)
		if err != nil {
			lib.Logger.Error("GetSharedList", err)
			return shareds, err
		}
		shareds = append(shareds, shared)
	}
	return shareds, nil
}

func (database *Database) GetShared(sid string) (SharedEntry, error) {
	shared := SharedEntry{}
	err := database.db.QueryRow(`
		SELECT sid, user_id, name, code, path, can_download, can_upload, current_count, max_count, current_upload_size, max_upload_size, time_limit, created_at
		FROM Shared
		WHERE sid =?;
	`, sid).Scan(
		&shared.Sid,
		&shared.UserId,
		&shared.Name,
		&shared.Code,
		&shared.Path,
		&shared.CanDownload,
		&shared.CanUpload,
		&shared.CurrentCount,
		&shared.MaxCount,
		&shared.CurrentUploadSize,
		&shared.MaxUploadSize,
		&shared.TimeLimied,
		&shared.CreatedAt)
	if err != nil {
		lib.Logger.Error("GetShared sid =", sid, err)
		return shared, err
	}
	return shared, nil
}

func (database *Database) DeleteShared(sid string) error {
	_, err := database.db.Exec(`
		DELETE FROM Shared
		WHERE sid =?;
	`, sid)
	if err != nil {
		lib.Logger.Error("DeleteShared", err)
		return err
	}
	return nil
}

func (database *Database) UpdateShared(shared SharedEntry) error {
	_, err := database.db.Exec(`UPDATE Shared SET code=?, name=?, can_download=?, can_upload=?, current_count=?, max_count=?, current_upload_size=?, max_upload_size=?, time_limit=? WHERE sid=?`,
		shared.Code,
		shared.Name,
		shared.CanDownload,
		shared.CanUpload,
		shared.CurrentCount,
		shared.MaxCount,
		shared.CurrentUploadSize,
		shared.MaxUploadSize,
		shared.TimeLimied,
		shared.Sid)
	if err != nil {
		lib.Logger.Error("UpdateShared", err)
		return err
	}
	return nil
}

func (database *Database) AddSharedHistory(she SharedHistoryEntry) error {
	now := time.Now()
	createdAt := now.Format(time.DateTime)
	_, err := database.db.Exec(`
		INSERT INTO SharedHistory (sid, information, action, ip, created_at)
		VALUES (?,?,?,?,?);
	`, she.Sid, she.Information, she.Action, she.Ip, createdAt)
	if err != nil {
		lib.Logger.Error("InsertSharedHistory", err)
		return err
	}
	return nil
}

func (database *Database) GetSharedHistory(sid string) ([]SharedHistoryEntry, error) {
	sharedHistories := []SharedHistoryEntry{}
	rows, err := database.db.Query(`
		SELECT sid, information, action, ip, created_at
		FROM SharedHistory
		WHERE sid =?
		ORDER BY created_at DESC;
	`, sid)
	if err != nil {
		lib.Logger.Error("GetSharedHistory", err)
		return sharedHistories, err
	}
	defer rows.Close()
	for rows.Next() {
		sharedHistory := SharedHistoryEntry{}
		err := rows.Scan(&sharedHistory.Sid, &sharedHistory.Information, &sharedHistory.Action, &sharedHistory.Ip, &sharedHistory.CreatedAt)
		if err != nil {
			lib.Logger.Error(err)
			return sharedHistories, err
		}
		sharedHistories = append(sharedHistories, sharedHistory)
	}

	return sharedHistories, nil
}
