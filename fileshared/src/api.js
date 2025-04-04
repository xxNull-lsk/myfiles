import axios from 'axios';
import { ref } from 'vue';

export let BASE_API_URL = '';
// 设置 BASE_API_URL 的函数
export const setBaseApiUrl = (url) => {
    if (!url.endsWith('/')) {
        url += '/';
    }
    BASE_API_URL = url;
};

let code = "";
export const setCode = (value) => {
    code = value;
};

let params = "";
export const setParams = (p) => {
    params = p;
    if (params !== '') {
        params = '&' + params;
    }
};

export let currentPath = ref('/');
export const setCurrentPath = (path) => {
    currentPath.value = path;
};
export const getUploadUrl = () => {
    return `${BASE_API_URL}api/shared/file?code=${code}&path=${currentPath.value}${params}`;
};

// 获取文件列表
export const fetchFileList = async (path) => {
    if (!path) {
        path = '/';
    }
    try {
        const url = `${BASE_API_URL}api/shared/files?code=${code}&path=${path}${params}`;
        const response = await axios.get(url);
        return response.data;
    } catch (error) {
        console.error('获取文件列表失败:', error);
        return {"code": 500, "message": "获取文件列表失败"};
    }
};

// 下载文件
export const downloadFile = (path) => {
    console.log(`downloadFile path: ${path}`);
    const url = `${BASE_API_URL}api/shared/file?code=${code}&app-name=web&path=${path}${params}`;
    // 使用 window.open 打开新窗口
    window.open(url, '_blank');
};

// 获取共享的基本信息
export const fetchSharedInfo = async (code) => {
    const url = `${BASE_API_URL}api/shared?code=${code}${params}`;
    try {
        const response = await axios.get(url);
        return response.data;
    } catch (error) {
        console.error('获取共享信息失败:', error);
        return {"code": 500, "message": "获取共享信息失败"};
    }
};

export const getServerInfo = async () => {
    try {
        const response = await axios.get(`${BASE_API_URL}api/version`);
        // 如果不是json格式，返回错误信息
        if (!response.headers['content-type'].includes('application/json')) {
            return { code: -1, message: "数据格式错误。" + response.headers['content-type'] };
        }
        if (response.status !== 200) {
            return { code: -1, message: `请求出错: ${response.statusText}` };
        }
        return response.data;
    } catch (error) {
        return { code: -1, message: `请求出错: ${error.message}` };
    }
};
