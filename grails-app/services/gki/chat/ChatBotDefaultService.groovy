package gki.chat

import grails.converters.JSON
import groovy.util.logging.Slf4j
import grails.transaction.Transactional
import org.springframework.messaging.simp.SimpMessagingTemplate
import groovy.xml.XmlUtil

@Slf4j
@Transactional
class ChatBotDefaultService {

  def infoEndpoint
  def healthEndpoint
  def metricsEndpoint
  
  def chatService
  SimpMessagingTemplate brokerMessagingTemplate

  ChatMessage message
  
  def commandList = [
    ['hello', '利用方法の説明(このメッセージ)', /(こんにちは|今日は|hello|help)/,
     { hello(this.message.username) }],
    ['makeChatRoom <ChatRoom名>', 'ChatRoomの作成', /(makeChatRoom .+|mcr .+)/,
     { makeChatRoom(this.message) }],
    ['deleteChatRoom <ChatRoom名>', 'ChatRoomの削除', /(deleteChatRoom .+|dcr .+)/,
     { deleteChatRoom(this.message) }],
    ['users', '接続している全ユーザと、有効な WebHook, FeedCrawlerのリストを表示', /users/,
     { displayAllConnectedUsers() }],
    ['addHook <WebHook名> <URL> [<Char Room>]', 'WebHookを追加する', /addHook.*/,
     { addHook(this.message) }],
    ['addFeed <Feed名> <URL> [<Char Room> <Interval>]', 'Feedを追加する', /addFeed.*/,
     { addFeed(this.message) }],
    ['info', 'Spring Boot Actuatorの infoを表示', /info/,
     { actuator() }],
    ['health', 'Spring Boot Actuatorの healthを表示', /health/,
     { actuator() }],
    ['metrics', 'Spring Boot Actuatorの metricsを表示', /metrics/,
     { actuator() }]
  ]

  
  void defaultHandler(ChatMessage message) {
    this.message = message
    commandList.each { commandName, desc, trigger, closure ->
      if( message.text ==~ trigger ) {
        closure.call()
      }
    }
  }


  void hello(String username){
    replyMessage username,
                 "こんにちは、${username}さん"

    def messageList = ChatMessage.findAllByUsername(username, [sort: 'id'])
    if( messageList.size >= 2 ){
      def lastMessage = messageList[-2]
            
      replyMessage username,
                   "あなたの最新のメッセージは"
      replyMessage username,
                   "${lastMessage.date} ${lastMessage.time} '${lastMessage.text}'"
      replyMessage username,
                   "です。"
    }

    replyMessage username,
                 "このチャットシステムで利用できるコマンドは以下です。"

    commandList.each { commandName, desc, trigger, closure ->
      replyMessage username, "&nbsp; &nbsp; ${XmlUtil.escapeXml commandName}: ${XmlUtil.escapeXml desc}"
      Thread.sleep(20)
    }    
  }


  void makeChatRoom(ChatMessage message) {
    def words = message.text.split(' ')
    if ( words.size() != 2) {
      replyMessage message.chatroom,
                   "${message.username}さん, ChatRoomの指定が正しくありません。",
                   true
    } else {
      if (ChatRoom.findByName(words[1])) {
        replyMessage message.chatroom,
                     "${message.username}さん, ChatRoom '${words[1]}'は既にあります。",
                     true
      } else {
        new ChatRoom(name: words[1]).save()
        replyMessage message.chatroom,
                     "${message.username}さん, ChatRoom '${words[1]}'を作成しました。",
                     true
        chatService.sendUserList()
      }
    }
  }
  
  
  void deleteChatRoom(ChatMessage message) {
    def words = message.text.split(' ')
    if ( words.size() != 2) {
      replyMessage message.chatroom,
                   "${message.username}さん, ChatRoomの指定が正しくありません。",
                   true
    } else {
      def target = ChatRoom.findByName(words[1])
      if (target) {
        target.delete()
        replyMessage message.chatroom,
                     "${message.username}さん, ChatRoom '${words[1]}'を削除しました。",
                     true
        chatService.sendUserList()
      } else {
        replyMessage message.chatroom,
                     "${message.username}さん, ChatRoom '${words[1]}'は有りません。",
                     true
      }
    }
  }


  void displayAllConnectedUsers() {
    def userList = ChatUser.findAllWhere(enabled: true)
    def whList = WebHook.findAllWhere(enabled: true)
    def fcList = FeedCrawler.findAllWhere(enabled: true)

    replyMessage message.username,
                 "${message.username}さん, 接続中のユーザは ${userList.size}名, 有効な WebHookは ${whList.size}, FeedCrawlerは ${fcList.size} です。"

    userList.each { user ->
      def chatroom = ChatRoom.get(user.chatroom)
      replyMessage message.username,
                   "${user.username}さんは '${chatroom.name}' にいます。"
    }

    whList.each { wh ->
      replyMessage message.username,
                   "WebHook '${wh.hookName}' (${wh.hookFrom}) が有効です。"
    }

    fcList.each { crawler ->
      replyMessage message.username,
                   "Feed '${crawler.name}' (${crawler.url}) が有効です。"
    }
  }

  
  void addHook(ChatMessage message) {
    def words = message.text.split(' ').toList()

    if( words.size() <= 2 ) {
      replyMessage message.username,
                   XmlUtil.escapeXml("addHook <WebHook名> <URL> [<Char Room>] と入力してください。")
      return
    }

    if( WebHook.findByHookName(words[1]) ) {
      replyMessage message.username,
              "すでに ${words[1]} という WebHook は登録されています。"
      return
    }

    if( words.size() == 3 ){
      words << ChatRoom.get(message.chatroom as long).name
    }

    new WebHook(hookName: words[1], hookFrom: words[2], chatroom: words[3]).save()
  }


  void addFeed(ChatMessage message) {
    def words = message.text.split(' ').toList()

    if( words.size() <= 2 ) {
      replyMessage message.username,
              XmlUtil.escapeXml("addFeed <Feed名> <URL> [<Char Room> <Interval>] と入力してください。")
      return
    }

    if( FeedCrawler.findByName(words[1]) ) {
      replyMessage message.username,
              "すでに ${words[1]} という Feed は登録されています。"
      return
    }

    if( words.size() == 3 ){
      words << ChatRoom.get(message.chatroom as long).name
    }

    if( words.size() == 4 ){
      words << 30
    }

    new FeedCrawler(name: words[1], url: words[2], chatroom: words[3], interval: words[4]).save()
  }


  void actuator() {
    def type = this.message.text
    def endpoints = ['info': infoEndpoint, 'health': healthEndpoint,
                     'metrics': metricsEndpoint
                    ]
    def endpoint = endpoints[type]

    replyMessage message.username,
                 "${message.username}さん, このチャットサーバの ${type}です。"

    def result
    if( type == 'health' ) {
      def health = endpoint.invoke()
      def status = health.getStatus()

      replyMessage message.username, "status : ${status}"
      result = health.getDetails()
    } else {
      result = endpoint.invoke()
    }
                 
    result.each { key, value ->
      replyMessage message.username, "${key} : ${value}"
      Thread.sleep(20)
    }
  }
  

  void webhook(payload) {
    def url = payload.repository.html_url

    log.info url
    def wh = WebHook.findByHookFrom(url)
    if( !wh || !wh.enabled ) return
    
    def roomList = wh.chatroom

    if( roomList ) {
      roomList = ChatRoom.findByName roomList
    } else {
      roomList = ChatRoom.findAll()
    }

    roomList.each { room ->
      def to = room.id as String

      if( payload.pusher ) {
        replyMessage to, "レポジトリに Pushされました。", true, wh.hookName
      } else if( payload.issue ) {
        if( payload.action == 'opened' ) {
          replyMessage to, "レポジトリに Issueが作成されました。", true, wh.hookName
        } else if( payload.action == 'closed' ) {
          replyMessage to, "レポジトリの Issueがクローズされました。", true, wh.hookName
        } else if( payload.action == 'reopened' ) {
          replyMessage to, "レポジトリの Issueが再開されました。", true, wh.hookName
        } else if( payload.action == 'created' && payload.comment ) {
          replyMessage to, "レポジトリの Issueにコメントが追加されました。", true, wh.hookName
        }
      } else if( payload.pull_request ) {
        if( payload.action == 'opened' ) {
          replyMessage to, "レポジトリに Pull Requestが作成されました。", true, wh.hookName
        } else if( payload.action == 'closed' ) {
          replyMessage to, "レポジトリの Pull Requestがクローズされました。", true, wh.hookName
        } else if( payload.action == 'reopened' ) {
          replyMessage to, "レポジトリの Pull Requestが再開されました。", true, wh.hookName
        }
      }

      replyMessage to, "repository: <a href='${url}'>${url}</a>", true, wh.hookName

      if( payload.pusher ) {
        replyMessage to, "ref: ${payload.ref}", true, wh.hookName
      }

      if( payload.issue ) {
        def issueurl = "${url}/issues/${payload.issue.number}"
        replyMessage to, "issue: <a href='${issueurl}'>No. ${payload.issue.number}</a>", true, wh.hookName
        replyMessage to, "title: ${payload.issue.title}", true, wh.hookName
      }

      if( payload.pull_request ) {
        def prurl = "${url}/pull/${payload.pull_request.number}"
        replyMessage to, "pull request: <a href='${prurl}'>No. ${payload.pull_request.number}</a>", true, wh.hookName
        replyMessage to, "title: ${payload.pull_request.title}", true, wh.hookName
      }

      if( payload.comment ) {
        replyMessage to, "comment: ${payload.comment.body}", true, wh.hookName
      }

      if( payload.sender ) {
        replyMessage to, "by: ${payload.sender.login}", true, wh.hookName
      }

      replyMessage to, "<hr/>", true, wh.hookName
    }
  }

  
  void replyMessage(String to, String message,
                    boolean persistence = false,
                    String replyname = 'gkibot') {
    String replyto = "/topic/${to}"
    def msg = new ChatMessage(text: message, username: replyname)

    if (persistence) {
      msg.status = 'fixed'
      msg.chatroom = to

      log.info msg.toString()
      msg.save()
    }

    brokerMessagingTemplate.convertAndSend replyto, (msg as JSON).toString()
  }
}
