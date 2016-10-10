package gki.chat

import groovy.transform.ToString

@ToString(includeNames=true)
class FeedCrawler {
  String name = ''
  String url = ''
  String chatroom = ''
  String lastFeed = ''
  Long interval = 30  // in min.
  Long countdown = 0
  boolean enabled = true

  static constraints = {
    name blank: false, editable: true
    url blank: false, editable: true, maxSize: 1024
    chatroom blank: true, editable: true, nullable: true
    lastFeed editable: false, blank: true, nullable: true, display: false, maxSize: 1024
    interval editable: true
    countdown editable: false, display: false
    enabled editable: true
  }
}
