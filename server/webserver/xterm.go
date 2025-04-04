package webserver

import (
	"crypto/tls"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"log"
	"myfileserver/lib"
	"net/http"
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/gorilla/websocket"
	"golang.org/x/crypto/ssh"
)

var console_upgrader = websocket.Upgrader{
	ReadBufferSize:   1024,
	WriteBufferSize:  1024,
	HandshakeTimeout: time.Hour * 8,
}

type ConsoleResponse struct {
	DataType string `json:"type"`
	Data     string `json:"data"`
}

type ConsoleResize struct {
	Cols int `json:"cols"`
	Rows int `json:"rows"`
}

type XtermConfig struct {
	Host     string `json:"host"`
	Port     int    `json:"port"`
	Username string `json:"username"`
	Password string `json:"password"`
	AuthKey  string `json:"auth_key"`
	CheckIn  string `json:"checkin"`
}

func consoleResponse(data_type string, data string) (p []byte) {
	resp := ConsoleResponse{
		DataType: data_type,
		Data:     data,
	}
	msg, err := json.Marshal(resp)
	if err != nil {
		log.Fatal(err, resp)
	}
	return msg
}

func (ws *WebServer) ReqCreateXtermWebSocket() gin.HandlerFunc {
	return func(c *gin.Context) {
		loginUserInfo := getLoginUser(c)
		path, succeed := getPath(c)
		var xterm_config XtermConfig
		if succeed {
			filePath := filepath.Join(ws.RootDir, loginUserInfo.UserEntry.RootDir, path)

			data, err := os.ReadFile(filePath)
			if err != nil {
				log.Println(err)
				c.JSON(http.StatusOK, gin.H{
					"code":    1000,
					"message": err.Error(),
				})
				return
			}
			err = json.Unmarshal(data, &xterm_config)
			if err != nil {
				log.Println(err)
				c.JSON(http.StatusOK, gin.H{
					"code":    1000,
					"message": err.Error(),
				})
				return
			}
		} else {
			err := c.ShouldBindJSON(&xterm_config)
			if err != nil {
				lib.Logger.Errorw("invalid body: ", err)
				c.JSON(http.StatusOK, gin.H{
					"code":    1000,
					"message": err.Error(),
				})
				return
			}
		}
		environments, err := ws.Database.GetUserSetting(loginUserInfo.UserEntry.Id, "environments")
		if err != nil {
			lib.Logger.Errorw("get user setting failed", "err", err)
		} else {
			envs := make(map[string]string)
			err = json.Unmarshal([]byte(environments.Value), &envs)
			if err != nil {
				lib.Logger.Errorw("get environments failed", "err", err)
			} else {
				for k, v := range envs {
					xterm_config.Host = strings.ReplaceAll(xterm_config.Host, "${env:"+k+"}", v)
					xterm_config.Username = strings.ReplaceAll(xterm_config.Username, "${env:"+k+"}", v)
					xterm_config.Password = strings.ReplaceAll(xterm_config.Password, "${env:"+k+"}", v)
					xterm_config.AuthKey = strings.ReplaceAll(xterm_config.AuthKey, "${env:"+k+"}", v)
					xterm_config.CheckIn = strings.ReplaceAll(xterm_config.CheckIn, "${env:"+k+"}", v)
				}
			}
		}
		lib.Logger.Infow("check in ...", "url", xterm_config.CheckIn)
		if xterm_config.CheckIn != "" {
			xterm_config.CheckIn = strings.ReplaceAll(xterm_config.CheckIn, "${host}", xterm_config.Host)
			transport := &http.Transport{
				TLSClientConfig: &tls.Config{InsecureSkipVerify: true},
			}
			httpClient := &http.Client{Transport: transport}
			_, err := httpClient.Get(xterm_config.CheckIn)
			if err != nil {
				lib.Logger.Errorw("check in failed", "url", xterm_config.CheckIn, "err", err)
				c.JSON(http.StatusOK, gin.H{
					"code":    1000,
					"message": err.Error(),
				})
				return
			}
			lib.Logger.Infow("check in succeed", "url", xterm_config.CheckIn)
		}
		console_upgrader.CheckOrigin = func(r *http.Request) bool {
			return true
		}
		conn, err := console_upgrader.Upgrade(c.Writer, c.Request, nil)
		if err != nil {
			lib.Logger.Error("Upgrade failed!", err)
			c.JSON(http.StatusOK, gin.H{
				"code":    1000,
				"message": err.Error(),
			})
			return
		}

		tmp := c.Query("width")
		if tmp == "" {
			tmp = "80"
		}
		width, _ := strconv.Atoi(tmp)
		tmp = c.Query("height")
		if tmp == "" {
			tmp = "160"
		}
		height, _ := strconv.Atoi(tmp)

		auth := []ssh.AuthMethod{ssh.Password(xterm_config.Password)}
		if xterm_config.AuthKey != "" {
			signer, err := ssh.ParsePrivateKey([]byte(xterm_config.AuthKey))
			if err != nil {
				defer conn.Close()
				lib.Logger.Error("ssh key signer failed:", err)
				err := conn.WriteMessage(websocket.TextMessage, consoleResponse("error", "ssh key signer failed: "+err.Error()))
				if err != nil {
					wsErr(conn, c.Request, http.StatusInternalServerError, err)
				}
				return
			}
			auth = []ssh.AuthMethod{ssh.PublicKeys(signer)}
		}
		sshServer := xterm_config.Host + ":" + strconv.Itoa(xterm_config.Port) + ""
		if sshServer == "" {
			sshServer = "localhost:22"
		}
		config := &ssh.ClientConfig{
			User:            xterm_config.Username,
			Auth:            auth,
			HostKeyCallback: ssh.InsecureIgnoreHostKey(),
		}
		lib.Logger.Infow("Dial in ...", "sshServer", sshServer)
		ssh_conn, err := ssh.Dial("tcp", sshServer, config)
		if err != nil {
			defer conn.Close()
			lib.Logger.Error("unable to coDialnnect:", err)
			err := conn.WriteMessage(websocket.TextMessage, consoleResponse("error", "unable to coDialnnect: "+err.Error()))
			if err != nil {
				wsErr(conn, c.Request, http.StatusInternalServerError, err)
			}
			return
		}
		session, err := ssh_conn.NewSession()
		if err != nil {
			defer ssh_conn.Close()
			defer conn.Close()

			lib.Logger.Error("unable to NewSession:", err)
			err := conn.WriteMessage(websocket.TextMessage, consoleResponse("error", "unable to NewSession: "+err.Error()))
			if err != nil {
				wsErr(conn, c.Request, http.StatusInternalServerError, err)
			}
		}

		go ssh_proc(conn, ssh_conn, session, width, height)
	}
}

type SshStdout struct {
	ssh *Ssh
}

type SshStderr struct {
	ssh *Ssh
}

type Ssh struct {
	web     *websocket.Conn
	session *ssh.Session
	stdout  *SshStdout
	stderr  *SshStderr
}

const (
	WSWriteDeadline = 1000 * time.Second
)

func wsErr(ws *websocket.Conn, r *http.Request, status int, err error) {
	txt := http.StatusText(status)
	if err != nil || status >= 400 {
		log.Printf("%s: %v %s %v", r.URL.Path, status, r.RemoteAddr, err)
	}
	if err := ws.WriteControl(websocket.CloseInternalServerErr, []byte(txt), time.Now().Add(WSWriteDeadline)); err != nil { //nolint:shadow
		log.Print(err)
	}
}

func (selfSsh *SshStdout) Write(p []byte) (n int, err error) {
	data := base64.StdEncoding.EncodeToString(p)
	err = selfSsh.ssh.web.WriteMessage(websocket.TextMessage,
		consoleResponse("stdout", data))
	if err != nil {
		lib.Logger.Error("WriteMessage stdout failed.", err)
		return 0, err
	}
	return len(p), nil
}

func (selfSsh *SshStderr) Write(p []byte) (n int, err error) {
	data := base64.StdEncoding.EncodeToString(p)
	err = selfSsh.ssh.web.WriteMessage(websocket.TextMessage,
		consoleResponse("stderr", data))
	if err != nil {
		lib.Logger.Error("WriteMessage stderr failed.", err)
		return 0, err
	}
	return len(p), nil
}

func (selfSsh *Ssh) Read(p []byte) (n int, err error) {
	_, msg, err := selfSsh.web.ReadMessage()
	if err != nil {
		log.Printf("%v", err)
		return 0, err
	}
	if string(msg) == "heartbeat" {
		selfSsh.web.WriteMessage(websocket.TextMessage, msg)
		return 0, nil
	}
	var con_msg ConsoleResponse
	err = json.Unmarshal(msg, &con_msg)
	if err != nil {
		log.Printf("%v", err)
		return 0, err
	}
	switch con_msg.DataType {
	case "stdin":
		{
			data := []byte(con_msg.Data)
			decodedLen := base64.StdEncoding.DecodedLen(len(con_msg.Data))
			if decodedLen > len(p) {
				lib.Logger.Info("base64.StdEncoding.Decode failed.", err)
				return 0, fmt.Errorf("buffer too small")
			}
			n, err := base64.StdEncoding.Decode(p, data)
			if err != nil {
				lib.Logger.Info("base64.StdEncoding.Decode failed.", err)
				return 0, err
			}
			return n, nil
		}
	case "resize":
		{
			var resize ConsoleResize
			err = json.Unmarshal([]byte(con_msg.Data), &resize)
			if err != nil {
				lib.Logger.Error("resize failed. %v", err)
				return 0, nil
			}
			err = selfSsh.session.WindowChange(resize.Rows, resize.Cols)
			if err != nil {
				lib.Logger.Error("WindowChange failed! %v", err)
				return 0, nil
			}
			return 0, nil
		}
	case "keepalive":
		{
			return 0, nil
		}
	}
	return 0, nil
}

func ssh_proc(conn *websocket.Conn, ssh_conn *ssh.Client, session *ssh.Session, width int, height int) {
	defer conn.Close()
	defer session.Close()
	defer ssh_conn.Close()
	conn.SetCloseHandler(func(code int, txt string) error {
		session.Close()
		ssh_conn.Close()
		return nil
	})

	client := &Ssh{
		web:     conn,
		session: session,
	}
	client.stdout = &SshStdout{
		ssh: client,
	}
	client.stderr = &SshStderr{
		ssh: client,
	}

	session.Stderr = client.stderr
	session.Stdout = client.stdout
	session.Stdin = client
	modes := ssh.TerminalModes{
		ssh.ECHO: 1,
	}
	if width <= 0 {
		width = 80
	}
	if height <= 0 {
		height = 160
	}
	err := session.RequestPty("xterm-256color", height, width, modes)
	if err != nil {
		lib.Logger.Error("unable to session RequestPty:", err)
		return
	}
	err = session.Shell()
	if err != nil {
		lib.Logger.Error("unable to session Shell: ", err)
		return
	}
	err = session.Wait()
	if err != nil {
		lib.Logger.Error("Session end: ", err)
		return
	}
}
