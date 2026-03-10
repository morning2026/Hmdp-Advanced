package com.hmdp;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.junit.jupiter.api.Test;

@SpringBootTest
public class test {

    @Autowired
    private StringRedisTemplate redisTemplate;

    @Test
    public void testConnection() {
        // 测试写入
        redisTemplate.opsForValue().set("test", "ok");

        // 测试读取
        String value = redisTemplate.opsForValue().get("test");
        System.out.println("Redis 连接正常，测试值: " + value);
    }
}