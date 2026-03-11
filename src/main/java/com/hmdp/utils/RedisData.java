package com.hmdp.utils;

import lombok.Data;

import java.time.LocalDateTime;

@Data
public class RedisData {
    private LocalDateTime expireTime;
    // 为了避免侵入性编程没有采用继承
    private Object data;
}
