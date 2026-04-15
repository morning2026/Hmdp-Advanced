# 诚意帮选 — 高并发电商秒杀平台

**二级缓存架构 / Lua 原子秒杀 / RocketMQ 异步削峰 / 多维度滑动窗口限流**

[![Spring Boot](https://img.shields.io/badge/Spring%20Boot-2.3.12-brightgreen)](https://github.com/morning2026/SincerelyChoice)
[![Redis](https://img.shields.io/badge/Redis-缓存%2B分布式锁-red)](https://github.com/morning2026/SincerelyChoice)
[![RocketMQ](https://img.shields.io/badge/RocketMQ-异步削峰-orange)](https://github.com/morning2026/SincerelyChoice)
[![License](https://img.shields.io/badge/License-MIT-yellow)](https://github.com/morning2026/SincerelyChoice)

**诚意帮选**是一个面向高并发场景的电商秒杀平台，为用户提供商家信息查询、秒杀优惠券、智能客服等功能，同时帮助商家推广优惠信息。项目重点解决秒杀场景下的超卖、重复下单、缓存击穿、系统过载等核心问题。

## 核心亮点

**1. 高并发读场景二级缓存架构**

- Redis + Caffeine 搭建二级缓存，热点商家和优惠券数据优先命中本地缓存，减少网络 IO
- 热点 Key 采用**逻辑过期**方案防止缓存击穿，异步刷新不阻塞请求
- **空值缓存**防止缓存穿透，**随机 TTL** 打散过期时间防止雪崩

**2. 缓存一致性保障**

- 写场景采用**延迟双删**保证数据库与 Redis 的最终一致性
- 同步发布删除消息至 RocketMQ，各服务节点订阅 Topic 后同步清除本地 Caffeine 缓存
- 删除失败时消息队列补偿重试 + TTL 兜底，双重保障一致性

**3. 秒杀防超卖与一人一单**

- Redis 存储库存和订单信息，**Lua 脚本原子性**校验库存与用户下单资格
- 数据库唯一索引兜底，彻底规避超卖和重复下单问题

**4. 秒杀流程异步化**

- 用户资格校验通过后，通过 **RocketMQ 消息队列**异步处理库存扣减与订单生成
- 实现秒杀流程解耦与异步削峰
- JMeter 压测：接口平均响应时间降低 **80%**，吞吐量提升 **57%**

**5. 超时订单自动关闭**

- 利用 **RocketMQ 延时消息**实现未支付订单到期自动关闭
- 消费者消费时同步释放库存，无需定时任务轮询

**6. 多维度滑动窗口限流**

- 基于 **Redis + AOP + 自定义注解**实现限流组件
- 支持全局、IP、用户三个维度灵活配置
- 防止系统过载、刷券与接口爬取

## 技术栈

| 组件 | 选型 |
|:--|:--|
| 框架 | Spring Boot 2.3.12 |
| ORM | MyBatis-Plus 3.4.3 |
| 数据库 | MySQL |
| 缓存 | Redis + Caffeine（二级缓存） |
| 分布式锁 | Redisson |
| 消息队列 | RocketMQ |
| 工具库 | Hutool、Lombok |

## 项目结构

```
SincerelyChoice/
└── src/
    └── main/
        ├── java/com/hmdp/
        │   ├── controller/     # 接口层
        │   ├── service/        # 业务逻辑（秒杀、缓存、限流等）
        │   ├── mapper/         # MyBatis-Plus Mapper
        │   ├── entity/         # 实体类
        │   ├── dto/            # 数据传输对象
        │   └── utils/          # 工具类（分布式锁、限流、缓存工具等）
        └── resources/
            └── application.yaml
```

## 本地部署

### 前置条件

- JDK 8+
- MySQL 5.7+
- Redis 6+
- RocketMQ 4.x

### 第一步：初始化数据库

导入 `src/main/resources/db/` 下的 SQL 文件：

```bash
mysql -u root -p < hmdp.sql
```

### 第二步：配置 application.yaml

修改数据库、Redis、RocketMQ 连接信息：

```yaml
spring:
  datasource:
    url: jdbc:mysql://localhost:3306/hmdp
    username: root
    password: 你的密码
  redis:
    host: localhost
    port: 6379
```

### 第三步：启动服务

```bash
mvn spring-boot:run
```

## 关键设计说明

### 秒杀 Lua 脚本原子校验

```lua
-- 1. 判断库存是否充足
if tonumber(redis.call('get', stockKey)) <= 0 then
    return 1
end
-- 2. 判断用户是否已下单
if redis.call('sismember', orderKey, userId) == 1 then
    return 2
end
-- 3. 扣减库存，记录用户
redis.call('incrby', stockKey, -1)
redis.call('sadd', orderKey, userId)
return 0
```

### 限流注解使用示例

```java
@RateLimit(type = LimitType.USER, count = 5, time = 60)
@PostMapping("/seckill/voucher/{voucherId}")
public Result seckillVoucher(@PathVariable Long voucherId) {
    // ...
}
```

### 延迟双删流程

```
1. 删除 Redis 缓存
2. 更新数据库
3. 延迟 500ms 再次删除 Redis 缓存（防止并发读写导致脏数据回填）
4. 发布 MQ 消息通知各节点清除 Caffeine 本地缓存
```

## 压测结果

使用 JMeter 模拟 1000 并发用户秒杀场景：

| 指标 | 优化前 | 优化后 |
|:--|:--|:--|
| 平均响应时间 | ~800ms | ~160ms（↓80%） |
| 吞吐量（QPS） | ~320 | ~503（↑57%） |
| 超卖订单数 | 存在 | 0 |

## 常见问题

**Q: 启动报错 `Cannot connect to Redis`？**

检查 Redis 是否已启动，以及 `application.yaml` 中的 host/port 配置是否正确。

**Q: RocketMQ 消息消费失败怎么处理？**

RocketMQ 默认重试 16 次，超过后进入死信队列。可通过 RocketMQ Console 查看死信队列并手动处理。

**Q: 本地缓存 Caffeine 与 Redis 数据不一致？**

Caffeine 缓存设置了 TTL 兜底，最终会过期失效。若需立即一致，检查 RocketMQ 消费者是否正常订阅了缓存删除 Topic。

## 贡献与支持

如果这个项目对你有帮助，请给个 Star ⭐️！
