const { chromium } = require('playwright');
const fs = require('fs');

async function testSocks5Proxy() {
    console.log('[INFO] 开始 SOCKS5 代理测试...');
    console.log('[WARNING] Chromium 不支持 SOCKS5 认证，将使用 curl 测试');

    try {
        // 读取代理配置
        if (!fs.existsSync('proxy-config.env')) {
            throw new Error('未找到代理配置文件 proxy-config.env');
        }

        console.log('[INFO] 读取代理配置...');
        const configContent = fs.readFileSync('proxy-config.env', 'utf8');
        const config = {};

        configContent.split('\n').forEach(line => {
            if (line.includes('=') && !line.startsWith('#')) {
                const [key, value] = line.split('=', 2);
                config[key.trim()] = value.trim().replace(/^"/, '').replace(/"$/, '');
            }
        });

        const protocol = config.PROXY_PROTOCOL || 'http';
        const socks5Port = config.PROXY_SOCKS5_PORT || config.PROXY_PORT;
        const username = config.PROXY_USERNAME;
        const password = config.PROXY_PASSWORD;

        if (!socks5Port || !username || !password) {
            throw new Error('代理配置不完整');
        }

        if (protocol !== 'socks5' && protocol !== 'both') {
            throw new Error(`当前协议为 ${protocol}，不支持 SOCKS5 测试`);
        }

        console.log(`[INFO] 使用 SOCKS5 代理: ${username}@127.0.0.1:${socks5Port}`);
        console.log('[INFO] 使用 curl 测试 SOCKS5 连接...');
        console.log('');

        // 使用 curl 测试 SOCKS5
        const { execSync } = require('child_process');
        
        // 测试1: 获取 IP
        console.log('[TEST 1] 测试 IP 检测...');
        try {
            const result = execSync(
                `curl -s -m 10 --socks5 ${username}:${password}@127.0.0.1:${socks5Port} https://api.ipify.org?format=json`,
                { encoding: 'utf8' }
            );
            const ipInfo = JSON.parse(result);
            console.log(`[SUCCESS] ✓ 当前 IP: ${ipInfo.ip}`);
        } catch (e) {
            console.log('[ERROR] ✗ IP 检测失败');
            throw e;
        }

        // 测试2: 访问网站
        console.log('');
        console.log('[TEST 2] 测试网站访问...');
        const testUrls = [
            'https://example.com',
            'https://httpbin.org/get',
            'https://www.google.com',
            'https://sehuatang.org/',
            'https://sehuatang.net/'
        ];

        let successCount = 0;
        for (const url of testUrls) {
            try {
                execSync(
                    `curl -s -m 10 -o /dev/null -w "%{http_code}" --socks5 ${username}:${password}@127.0.0.1:${socks5Port} ${url}`,
                    { encoding: 'utf8', stdio: 'pipe' }
                );
                console.log(`[SUCCESS] ✓ ${url}`);
                successCount++;
            } catch (e) {
                console.log(`[ERROR] ✗ ${url}`);
            }
        }

        console.log('');
        console.log(`[SUCCESS] 成功访问 ${successCount}/${testUrls.length} 个网站`);
        console.log('');
        console.log('[SUCCESS] ✅ SOCKS5 代理测试完成！');
        console.log('');
        console.log('[INFO] 注意: Playwright/Chromium 不支持 SOCKS5 认证');
        console.log('[INFO] 如需在 Playwright 中使用 SOCKS5，请使用 HTTP 代理');
        
        return true;

    } catch (error) {
        console.error('');
        console.error('[ERROR] ❌ 测试失败:', error.message);
        return false;
    }
}

// 运行测试
testSocks5Proxy().then(success => {
    process.exit(success ? 0 : 1);
});
