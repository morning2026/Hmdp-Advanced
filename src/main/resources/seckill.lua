--- 1. 参数列表
--- 1.1. 优惠券id
local voucherId = ARGV[1]
--- 1.2. 用户id
local userId = ARGV[2]
--- 1.3. 订单id
local orderId = ARGV[3]


--- 2. 数据key
--- 2.1. 优惠券库存key
local stockKey = 'seckill:stock:' .. voucherId
--- 2.2. 用户秒杀订单key
local orderKey = 'seckill:order:' .. voucherId

--- 3. 脚本业务
--- 3.1. 检查优惠券库存是否足够
local stock = tonumber(redis.call('GET', stockKey)) or 0
if (stock <= 0) then
    --- 3.1.1. 库存不足，返回1
    return 1
end
--- 3.2. 检查用户是否已秒杀过
if (redis.call('SISMEMBER', orderKey, userId)==1) then
    --- 3.2.1. 用户已秒杀，返回2
    return 2
end
--- 3.3. 扣减库存
redis.call('DECR', stockKey)
--- 3.4. 记录用户秒杀订单
redis.call('SADD', orderKey, userId)
--- 3.5. 发送消息到消息队列中
redis.call('XADD', 'stream.orders', '*', 'userId', userId, 'voucherId', voucherId, 'id', orderId)
return 0

