package webserver

import (
	"myfileserver/db"
	"myfileserver/lib"
	"sync"
	"time"
)

type UserInfo struct {
	UserName     string
	UserToken    string
	LoginAt      time.Time
	FirstLoginAt time.Time
	UserEntry    db.UserEntry
}

// Singleton 是单例模式类
type Singleton struct {
	Lock             sync.Mutex
	Database         *db.Database
	Tokens           map[string]UserInfo
	PackageDownloads map[string]*lib.ProgressReaderWriter // 打包下载任务的信息
	UploadTask       map[string]*UploadFileEntry          // 分片上传任务的信息
}

var (
	instance *Singleton
	once     sync.Once
)

// GetInstance 用来获取单例对象的方法
func GetInstance() *Singleton {
	once.Do(func() {
		instance = &Singleton{} // 这里可以初始化单例的一些属性
	})
	return instance
}
