package db

import (
	"database/sql"
	"myfileserver/lib"
	"os"
	"path/filepath"

	_ "github.com/mattn/go-sqlite3"
)

type Database struct {
	FileName string
	db       *sql.DB
}

func (database *Database) Open() error {
	lib.Logger.Infoln("Open database ", database.FileName)
	if !lib.IsExist(database.FileName) {
		lib.Logger.Infoln("Create database ", database.FileName)
		os.MkdirAll(filepath.Dir(database.FileName), 0777)
		_, err := os.Create(database.FileName)
		if err != nil {
			lib.Logger.Error("Create database failed!", database.FileName, err)
			return err
		}
	}
	db, err := sql.Open("sqlite3", database.FileName)
	if err != nil {
		lib.Logger.Error("Open database failed!", database.FileName, err)
		return err
	}

	database.db = db
	err = database.InitUser()
	if err != nil {
		lib.Logger.Error("Init user failed!", err)
		return err
	}
	err = database.InitFavorites()
	if err != nil {
		lib.Logger.Error("Init favorites failed!", err)
		return err
	}
	return database.InitShared()
}

func (database *Database) Close() {
	database.db.Close()
}
