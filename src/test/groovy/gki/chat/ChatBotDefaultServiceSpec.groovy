package gki.chat

import grails.test.mixin.TestFor
import spock.lang.Specification

/**
 * See the API for {@link grails.test.mixin.services.ServiceUnitTestMixin} for usage instructions
 */
@TestFor(ChatBotDefaultService)
class ChatBotDefaultServiceSpec extends Specification {

  def setup() {
  }

  def cleanup() {
  }

  void "test initialization"() {
  expect:
    service != null
    service.commandList != null
  }
}
