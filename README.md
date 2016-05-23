# Scheduler Web API Service

## APIs

### 如何读该API的文档
- 一些例子和约定
    - GET /api/v1/messages  token
        - Message[]

    - 解释  
        - GET:              HTTP Method
        - /api/v1/messages: Relative path
        - token:            需要token认证
        - 假设站点主机名为api.a1ex.wang, 则完整的HTTP请求为
            - GET http://api.a1ex.wang/api/v1/messages?token=1234xxxxx
        - 返回的JSON格式
            - { "status": "ok", "reason": "ok", messages: \[{"id": xxx, ...}\, ...\] }
            - status:   状态, 取值见下面status部分的说明
            - reason:   如果失败, 则是一个可读的字符串, 显示失败的原因
            - messages: 由于文档中写了Message[], 所以对应此字段名为messages, 类型是Message数组
            - 如果是POST请求, 用data: xxx表示POST的数据
    - status的取值
        - ok: 成功
        - not_found: uri错误
        - parameter_error: 参数错误
        - unauthorized: token错误
        - unknown_error: 服务器崩溃了
    - 各种类型的定义
        - Message
            - Integer id
            - Integer user_id
            - String title
            - String source
            - String uri
            - String description
            - String content
            - ... ?
        - SimpleMessage
            - Integer id
            - Integer user_id
            - String title
            - String source
            - String url

### For clients' polling
- GET /api/v1/unread_messages   token
    - SimpleMessage[] simple_messages
    - 获取所有未读的消息列表
- GET /api/v1/sources/:source_name/unread_messages  token
    - SimpleMessage[] simple_messages
    - 获取某个数据源的所有未读消息列表

### For message pushing
- POST /api/v1/unread_messages?user_id=1    token, 这个user_id和token是message source用户的
    - data: SimpleMessage 
    - return: message_id: 1
    - 添加消息
    
### Authorization Server(是和Scheduler独立的服务, 但是他们即使部署在同一个端口, URI也不会冲突)

- GET /api/v1/user_info token
    - String user_id
    - String username

- POST /api/v1/login?username=&password=
    - String user_id
    - String token
    
### cURL例子
- 登陆

        $ curl "http://auth.soa.a1ex.wang/api/v1/login" -d "username=learn&password=123"
        => {"status":"ok","user_id":1,"token":"d019b242f7d73fa5954a6596c0ace90a8589f2799a1f1891"}⏎
        
- 推送消息

        $ curl "http://scheduler.soa.a1ex.wang/api/v1/unread_messages" -d 'token=d019b242f7d73fa5954a6596c0ace90a8589f2799a1f1891&json={"simple_message": {"title": "hello", "user_id":2,"source":"learn","url":"http://www.baidu.com" }}'
        => {"message_id":11,"status":"ok"}⏎ 

- 获取消息

        $ curl "http://scheduler.soa.a1ex.wang/api/v1/unread_messages?token=1a250ec0aa9978eae119546c6d5c5e2a16c3fcd330642a97"
        
        =>
        {
            "status":"ok",
            "simple_messages":[
                {
                    "id":11,
                    "title":"hello",
                    "user_id":"2",
                    "url":"http://www.baidu.com",
                    "source":"learn",
                    "description":null,
                    "msg_type":null,
                    "created_at":"2016-05-06T05:40:53.342Z",
                    "updated_at":"2016-05-06T05:40:53.342Z"
                }
            ]
        }