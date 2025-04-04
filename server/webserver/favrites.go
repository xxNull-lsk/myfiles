package webserver

import (
	"myfileserver/db"
	"net/http"
	"strconv"
	"time"

	"github.com/gin-gonic/gin"
)

func (ws *WebServer) ReqGetFavoritesList() gin.HandlerFunc {
	return func(c *gin.Context) {
		loginUserInfo := getLoginUser(c)
		sharedList, err := ws.Database.GetFavoritesList(loginUserInfo.UserEntry.Id)
		if err != nil {
			c.JSON(http.StatusOK, gin.H{
				"code":    1000,
				"message": err.Error(),
			})
			return
		}
		c.JSON(http.StatusOK, gin.H{
			"code":    0,
			"message": "get shared list succeed",
			"data":    sharedList,
		})
	}
}

func (ws *WebServer) ReqCreateFavorites() gin.HandlerFunc {
	return func(c *gin.Context) {
		loginUserInfo := getLoginUser(c)
		var req struct {
			Name string `json:"name"`
			Path string `json:"path"`
		}
		err := c.BindJSON(&req)
		if err != nil {
			c.JSON(http.StatusOK, gin.H{
				"code":    1000,
				"message": err.Error(),
			})
			return
		}
		favorites := db.FavoritesEntry{
			Name:      req.Name,
			Path:      req.Path,
			UserId:    loginUserInfo.UserEntry.Id,
			CreatedAt: time.Now().Format(time.DateTime),
		}
		id, err := ws.Database.AddFavorites(favorites)
		if err != nil {
			c.JSON(http.StatusOK, gin.H{
				"code":    1000,
				"message": err.Error(),
			})
			return
		}
		c.JSON(http.StatusOK, gin.H{
			"code":    0,
			"message": "create favorites succeed",
			"data":    id,
		})
	}
}

func (ws *WebServer) ReqDeleteFavorites() gin.HandlerFunc {
	return func(c *gin.Context) {
		loginUserInfo := getLoginUser(c)
		id := c.Query("id")
		if id == "" {
			c.JSON(http.StatusOK, gin.H{
				"code":    1000,
				"message": "id is empty",
			})
			return
		}
		favoritesId, err := strconv.ParseInt(id, 10, 64)
		if err != nil {
			c.JSON(http.StatusOK, gin.H{
				"code":    1000,
				"message": err.Error(),
			})
			return
		}
		favoritesEntry, err := ws.Database.GetFavorites(favoritesId)
		if err != nil {
			c.JSON(http.StatusOK, gin.H{
				"code":    1000,
				"message": err.Error(),
			})
			return
		}
		if favoritesEntry.UserId != loginUserInfo.UserEntry.Id && !loginUserInfo.UserEntry.IsAdmin {
			c.JSON(http.StatusOK, gin.H{
				"code":    1000,
				"message": "permission denied",
			})
			return
		}
		err = ws.Database.DeleteFavorites(favoritesId)
		if err != nil {
			c.JSON(http.StatusOK, gin.H{
				"code":    1000,
				"message": err.Error(),
			})
			return
		}

		ws.Database.AddUserHistory(db.UserHistoryEntry{
			UserId:   loginUserInfo.UserEntry.Id,
			UserName: loginUserInfo.UserEntry.Name,
			Action:   "delete_favorites",
			Information: ws.getRequestInfo(c, map[string]string{
				"favorites_id":   id,
				"favorites_name": favoritesEntry.Name,
				"favorites_path": favoritesEntry.Path,
			}),
			Ip: c.ClientIP(),
		})
		c.JSON(http.StatusOK, gin.H{
			"code":    0,
			"message": "delete favorites succeed",
		})
	}
}
