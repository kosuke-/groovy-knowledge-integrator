# WebSocket Stomp Client
stompClient = {}
lastUser = {}
lastMessage = ''
tempMessages = {}
iconIndex = 0
notificationTimeout = 5000
canNotify = typeof window.Notification isnt 'undefined'
mom = moment()
startTime = mom.format("YYYY-MM-DD HH:mm:ss")
today = mom.format("YYYY/MM/DD")
lastNotified = startTime


$('#temporaryInput').on 'click', (event) ->
    $('#chatMessage').popover('toggle')


# display DateTimePicker inline
$('#datetimepickerInline').datetimepicker({
    inline: true
    locale: 'ja'
    showTodayButton: true
    format: 'yyyy-MM-dd'
    dayViewHeaderFormat: 'M月 YYYY年'
})


$('div').on 'click', (event) ->
    if event.target.id.substring(0,7) is 'message'
        msg = event.target.textContent.trim()
        $('#chatMessage').val "> #{msg}"
        $('#chatMessage').focus()
    

$('#datetimepickerInline').on 'dp.clicked', (event) ->
    updateMessageNumberBadges()


# DateTimePicker changed eventhandler
$('#datetimepickerInline').on 'dp.change', (event) ->
    updateMessageNumberBadges()
    selectedDate = moment(event.date).format('YYYY-MM-DD')

    if selectedDate > moment().format('YYYY-MM-DD')
        return

    $('#area00').append """
    <hr/>
    <div class="row" style="background-color: lightgray;">
    <div class="col-sm-11 col-sm-offset-1">
        <div class="row">
            <i>#{selectedDate}</i>
        </div>
    </div>
    </div>
    """

    lastUser = {}
    message = {}
    message.text = selectedDate
    message.status = ''
    message.chatroom = $('#chatRoomSelected').val()
    message.username = $('#userName').val()

    stompClient.send "/app/log", {}, JSON.stringify(message)
    $('#chatMessage').focus()
    $('#area00').scrollTop(($("#area00")[0].scrollHeight))


# update Date, Time
setInterval ->
        $('#currentTime').text moment().format('MM/DD HH:mm')
    , 1000


# update temporary input
setInterval ->
        message = {}
        message.text = _.escape($.trim($('#chatMessage').val()))
        message.status = 'temp'
        message.chatroom = $('#chatRoomSelected').val()
        message.username = $('#userName').val()

        if message.text isnt ''
            stompClient.send "/app/tempMessage", {}, JSON.stringify(message)
    , 700


# update message number badge on datepicker
updateMessageNumberBadges = () ->
    $('.day').each (index, day) ->
        targetDay = day.getAttribute('data-day')
        if targetDay <= today
            updateMessageNumberBadgeOnDay targetDay


updateMessageNumberBadgeOnDay = (targetDay) ->
    crs = $('#chatRoomSelected').val()
    count = sessionStorage.getItem(crs + '_' + targetDay)
    if count?
        setMessageNumberBadgeOnDay(targetDay, count)
    else if targetDay <= today
        $.ajax {
            url: "countMessages"
            data: { room: $('#chatRoomSelected').val(), day: targetDay }
        }
        .done ( msg ) ->
            setMessageNumberBadgeOnDay(msg.day, msg.count)
            if targetDay < today
                crs = $('#chatRoomSelected').val()
                sessionStorage.setItem(crs + '_' + msg.day, msg.count)

                
setMessageNumberBadgeOnDay = (day, count) ->
    dn = day.split('/')[2]
    if dn[0] is '0' then dn = dn[1]
    if '' + count is '0'
        $("[data-day='#{day}']").html "#{dn}"
    else
        $("[data-day='#{day}']").html "<div style='line-height:90%;'>#{dn}<br/><div class='label label-info' style='font-size:9.5px;'>.#{count}</div><div>"
        # $("[data-day='#{day}']").html "#{dn}<br/><div class='label label-info top-right' style='font-size:9.5px;'>.#{count}</div>"
        # $("[data-day='#{day}']").html "#{dn}<a style='font-size:9px; color:#000000;'>_#{count}</a>"


# store userName into localStorage
$('#userName').on 'keyup', ->
    localStorage['userName'] = $('#userName').val()


# subscribe UserName and ChatRoom
subscribeAll = () ->
    stompClient.subscribe "/topic/#{$('#userName').val()}", (message) ->
        onReceiveByUser(message)

    stompClient.subscribe "/topic/#{$('#chatRoomSelected').val()}", (message) ->
        onReceiveChatRoom(message)

    stompClient.subscribe "/topic/temp/#{$('#chatRoomSelected').val()}", (message) ->
        onReceiveTemporaryChatRoom(message)


# unsubscribe all subscriptions
unsubscribeAll = () ->
    _.each _.allKeys(stompClient.subscriptions), (it) ->
        stompClient.unsubscribe it


# update userName
$('#userName').focusout ->
    if $('#userName').val() isnt ''
        $('#uploadButton').val "upload image of #{$('#userName').val()}"
        unsubscribeAll()
        subscribeAll()

        message = {}
        message.text = ''
        message.status = ''
        message.chatroom = $('#chatRoomSelected').val()
        message.username = $('#userName').val()

        stompClient.send "/app/updateUser", {}, JSON.stringify(message)


# update ChatRoomSelected
$('#chatRoomSelected').on 'change', (event) ->
    updateMessageNumberBadges()
    mom = moment()
    lastNotified = mom.format("YYYY-MM-DD HH:mm:ss")

    $('#area00').html ''
    lastUser = ''

    unsubscribeAll()
    subscribeAll()

    selectedDate = $('#datetimepickerInline').data('DateTimePicker').date().format('YYYY-MM-DD')

    message = {}
#    message.text = moment().format('YYYY-MM-DD')
    message.text = selectedDate
    message.status = ''
    message.chatroom = $('#chatRoomSelected').val()
    message.username = $('#userName').val()

    stompClient.send "/app/updateUser", {}, JSON.stringify(message)
    stompClient.send "/app/log", {}, JSON.stringify(message)
    $('#chatMessage').focus()
#    $("a[title='Go to today']").click()


# send chat message
$('#chatMessage').on 'keyup', (event) ->
    if event.keyCode is 73 and event.ctrlKey is true  # Ctrl + i
        $('#chatMessage').val lastMessage
    else if $('#chatMessage').val() is ''
        message = {}
        message.text = ''
        message.status = 'temp'
        message.chatroom = $('#chatRoomSelected').val()
        message.username = $('#userName').val()

        stompClient.send "/app/tempMessage", {}, JSON.stringify(message)
    else if event.keyCode is 13 and $.trim($('#chatMessage').val()) isnt ''
        message = {}
        message.text = _.escape($.trim($('#chatMessage').val()))
        message.status = 'fixed'
        message.chatroom = $('#chatRoomSelected').val()
        message.username = $('#userName').val()

        stompClient.send "/app/message", {}, JSON.stringify(message)
        $('#chatMessage').val ''
        $('#chatMessage').focus()
        lastMessage = message.text


# heartbeat user
heartbeatUser = () ->
    message = {}
    message.text = ''
    message.status = 'heartbeat'
    message.chatroom = $('#chatRoomSelected').val()
    message.username = $('#userName').val()

    stompClient.send "/app/heartbeat", {}, JSON.stringify(message)


setInterval ->
        heartbeatUser()
    , 3000

    
# WebSocket user message receive eventhandler
onReceiveByUser = (message) ->
    console.log "@#{$('#userName').val()}: " +  message.body
    msg = JSON.parse(message.body)

    if msg.chatRoomList
        crlDef = ''
        _.each msg.chatRoomList, (it) ->
            crlDef += "<option value='#{it.id}'>#{it.name}</option>"
        $('#chatRoomSelected').html crlDef
        $('#chatRoomSelected').val msg.selected
    else if msg.userList
        tableDef = """<table class="table table-striped">
            <thead>
              <tr>
                <th>User Name</th>
                <th>Chatroom</th>
              </tr>
            </thead>
            <tbody>"""

        _.each msg.userList, (it) ->
            tableDef += """<tr>
                  <td style="width: 9em;">#{it.username}</td>
                  <td>#{it.chatroom}</td>
                </tr>"""

        tableDef += """</tbody>
          </table>"""

        $('#connectedUsersTable').html tableDef

        users = _.map msg.userList, (user) -> user.username
        tempMessages = _.pick tempMessages, users
        displayTempMessages()
    else if msg.status is 'closeTime'
        selectedDate = $('#datetimepickerInline').data('DateTimePicker').date().format('YYYY-MM-DD')
        $('#area00').append """
        <div class="row" style="background-color: lightgray;">
        <div class="col-sm-11 col-sm-offset-1">
            <div class="row">
                <i>#{selectedDate}</i>
            </div>
        </div>
        </div>
        <hr/>
        """
        $('#area00').scrollTop(($("#area00")[0].scrollHeight))
    else
        onReceiveChatRoom(message)


# WebSocket chat message receive eventhandler
onReceiveTemporaryChatRoom = (message) ->
    console.log "Chat Message Temporary: " + message.body
    msg = JSON.parse(message.body)

    tempMessages[msg.username] = msg.text

    if msg.text is ''
        tempMessages = _.omit(tempMessages, msg.username)
    displayTempMessages()


# display temporary messages
displayTempMessages = () ->
    updateMessageNumberBadgeOnDay(today)
    html = ''
    _.each _.pairs(tempMessages), (pair) ->
        html += "<u><strong>#{pair[0]}</strong></u> #{pair[1]}<hr/>"
    $('#temporaryInputPopover').html html


# WebSocket chat message receive eventhandler
onReceiveChatRoom = (message) ->
    console.log "Chat Message: " + message.body
    updateMessageNumberBadgeOnDay(today)
    msg = JSON.parse(message.body)

    tempMessages = _.omit(tempMessages, msg.username)
    displayTempMessages()
    
    if msg.text.match /^https{0,1}:\/\/.+/
        msg.text = "<a href='#{msg.text}'>#{msg.text}</a>"

    if lastUser is msg['username']
        $('#area00').append """
        <div class="row">
        <div class="col-sm-11 col-sm-offset-1">
            <div class="row" id="message#{msg['id']}" data-toggle="tooltip"
                 data-placement="left" title="#{msg['time']}">
                #{msg['text']}
            </div>
        </div>
        </div>
        """
    else
        iconIndex++
        $('#area00').append """
        <div class="row">
        <div class="col-sm-1" align="center" id="icon#{iconIndex}">
            <img id='image#{iconIndex}' src='/chat/icon?name=#{msg['username']}' style='height: 40px;'/>
        </div>
        <div class="col-sm-11">
            <div class="row">
                <strong>#{msg['username']}</strong>&nbsp;<i>#{msg.time}</i>
            </div>
            <div class="row" id="message#{msg['id']}" data-toggle="tooltip"
                 data-placement="left" title="#{msg['time']}">
                #{msg['text']}
            </div>
        </div>
        </div>
        """

        $("#image#{iconIndex}").on 'error', (error) ->
            error.currentTarget.parentNode.innerHTML = "<svg width='40' height='40' id='identicon#{('' + error.timeStamp).replace(/\./, '_')}'></svg>"
            jdenticon.update("#identicon#{('' + error.timeStamp).replace(/\./, '_')}", sha1(msg['username']))

    $('#area00').scrollTop(($("#area00")[0].scrollHeight))
    lastUser = msg['username']

    if msg['id']?
        $("#message#{msg['id']}").tooltip()
        textNoti = $("#message#{msg['id']}").text().trim()
    else
        textNoti = msg['text']

    optionsNoti =
        body: textNoti
        icon: "/chat/icon?name=#{msg['username']}"

    if canNotify and "#{msg['date']} #{msg['time']}" > lastNotified and $('#userName').val() isnt msg['username']
        tmpNoti = new Notification("#{msg['username']} / gki Chat", optionsNoti)
        setTimeout(tmpNoti.close.bind(tmpNoti), notificationTimeout)
        lastNotified = "#{msg['date']} #{msg['time']}"

    
# WebSocket connect eventhandler
onConnect = () ->
    subscribeAll()
    if canNotify then configNotification()

    $('#wsstatus').removeClass 'label-danger'
    $('#wsstatus').addClass 'label-info'
    $('#wsstatus').html 'OnLine'
    $('#wsstatus').tooltip({'placement': 'top', 'title': startTime})

    if $('#userName').val() isnt ''
        message = {}
        message.text = moment().format('YYYY-MM-DD')
        message.status = ''
        message.chatroom = $('#chatRoomSelected').val()
        message.username = $('#userName').val()

        stompClient.send '/app/addUser', {}, JSON.stringify(message)
        

# WebSocket disconnect eventhandler
onDisconnect = () ->
    $('#wsstatus').removeClass 'label-info'
    $('#wsstatus').addClass 'label-danger'
    $('#wsstatus').html 'OffLine'
    $('#wsstatus').tooltip('destroy')
    OffLineTime = mom.format("YYYY-MM-DD HH:mm:ss")
    $('#wsstatus').tooltip('show')
    $('#wsstatus').tooltip({'placement': 'bottom', 'title': OffLineTime})


# connect to WebSocket Server
connect = () ->
    # Connect WebSocket
    socket = new SockJS '/stomp'
    client = Stomp.over socket

    # WebSocket Connected
    client.connect {}, () ->
        stompClient = client
        stompClient.debug = null
        onConnect()
    , () ->
        onDisconnect()

    
# initialize display
$(document).ready ->
    $("#refresh").tooltip()
    $('#iconImageUploadPopover').popover()
    $('#chatMessage').popover()
    # Display username from localStorage if exists.
    if localStorage['userName']? and $('#userName').val()?
        $('#userName').val localStorage['userName']

        connect()

    if $('#userName').val()?
        $('#uploadButton').val "upload image of #{$('#userName').val()}"
#        $('#userIconImage').html "<img src='/chat/icon?name=#{$('#userName').val()}'  style='width: 40px; height: 40px;'>"

    updateMessageNumberBadges()
    

configNotification = () ->
    if Notification.permission is "granted"
        notification = new Notification("Web Notification is Active. / gki Chat")
        setTimeout(notification.close.bind(notification), 3000)
    else if Notification.permission isnt "denied"
        Notification.requestPermission (permission) ->
            if permission is "granted"
                notification = new Notification("Thank you. / gki Chat")
                setTimeout(notification.close.bind(notification), 3000)

