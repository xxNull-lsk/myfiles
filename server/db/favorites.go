package db

import (
	"myfileserver/lib"
	"time"
)

type FavoritesEntry struct {
	Id        int64  `json:"id"`
	Name      string `json:"name"`       // 分享名称
	UserId    int64  `json:"user_id"`    // 用户ID
	Path      string `json:"path"`       // 目录的路径
	CreatedAt string `json:"created_at"` // 创建时间
}

func (database *Database) InitFavorites() error {
	// 创建 Favorites 表，用于存储用户收藏的目录
	_, err := database.db.Exec(`
		CREATE TABLE IF NOT EXISTS Favorites (
			id INTEGER PRIMARY KEY AUTOINCREMENT,
			name TEXT NOT NULL,
			path TEXT NOT NULL,
			user_id INTEGER NOT NULL,
			created_at TEXT NOT NULL
		);
	`)
	if err != nil {
		lib.Logger.Error("InitFavorites", err)
		return err
	}

	return nil
}

func (database *Database) AddFavorites(favorites FavoritesEntry) (int64, error) {
	res, err := database.db.Exec(`
		INSERT INTO Favorites (name, path, user_id, created_at)
		VALUES (?,?,?,?);
	`, favorites.Name, favorites.Path, favorites.UserId, time.Now().Format(time.DateTime))
	if err != nil {
		lib.Logger.Error("AddFavorites: insert data failed!", err)
		return 0, err
	}
	id, err := res.LastInsertId()
	if err != nil {
		lib.Logger.Error("AddFavorites: get id failed!", err)
		return 0, err
	}
	return id, nil
}

func (database *Database) GetFavoritesList(user_id int64) ([]FavoritesEntry, error) {
	favorites := []FavoritesEntry{}
	rows, err := database.db.Query(`
		SELECT id, name, path, user_id, created_at
		FROM Favorites
		WHERE user_id =?;
	`, user_id)
	if err != nil {
		lib.Logger.Error("GetFavoritesList", err)
		return favorites, err
	}
	defer rows.Close()
	for rows.Next() {
		favorite := FavoritesEntry{}
		err := rows.Scan(
			&favorite.Id,
			&favorite.Name,
			&favorite.Path,
			&favorite.UserId,
			&favorite.CreatedAt)
		if err != nil {
			lib.Logger.Error("GetFavoritesList", err)
			return favorites, err
		}
		favorites = append(favorites, favorite)
	}
	return favorites, nil
}

func (database *Database) GetFavorites(id int64) (FavoritesEntry, error) {
	favorite := FavoritesEntry{}
	err := database.db.QueryRow(`
		SELECT id, name, path, user_id, created_at
		FROM Favorites
		WHERE id =?;
	`, id).Scan(
		&favorite.Id,
		&favorite.Name,
		&favorite.Path,
		&favorite.UserId,
		&favorite.CreatedAt)
	if err != nil {
		lib.Logger.Error("GetFavorites", err)
		return favorite, err
	}
	return favorite, nil
}

func (database *Database) DeleteFavorites(id int64) error {
	_, err := database.db.Exec(`
		DELETE FROM Favorites
		WHERE id =?;
	`, id)
	if err != nil {
		lib.Logger.Error("DeleteFavorites", err)
		return err
	}
	return nil
}
