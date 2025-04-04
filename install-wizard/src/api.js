import axios from 'axios';

export const getServerInfo = async () => {
    try {
        const response = await axios.get('/api/install');
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

export const doInstall = async (logger, server) => {
    try {
        const response = await axios.post('/api/install', {
            logger,
            server
        });
        // 如果不是json格式，返回错误信息
        if (!response.headers['content-type'].includes('application/json')) {
            return { code: -1, message: "数据格式错误。" + response.headers['content-type'] };
        }
        if (response.status !== 200) {
            return { code: -1, message: `请求出错: ${response.statusText}` };
        }
        return response.data;
    } catch (error) {
        return { code: -2, message: `安装失败: ${error.message}` };
    }
};
