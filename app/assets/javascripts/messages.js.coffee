$ -> # messages notifications
  container = $('.messages .notifications')
  return unless container.length

  container.find('#more-button').click ->
    $(this).addClass('disabled')
    $(this).html($(this).data('loading'))
    ids = []
    container.find('.notification-block').each ->
      ids.push($(this).data('id'))
    $.ajax
      url: location.href
      data:
        ajax: true
        excepted_ids: ids
      dataType: 'json'
      timeout: 5000
      success: (response) ->
        if response.is_last_page
          container.find('#more-button').remove()
        $.each response.data, (index, notification) ->
          list = container.find('#notifications')
          block = container.find('.template').clone().appendTo(list)
          block.removeClass('template')
          block.removeClass('hidden')
          block.addClass('notification-block')
          block.find('.content').html(notification.content)
          block.find('.time').html(notification.created_at)
          if notification.read
            block.find('.not-read').addClass('hidden')
          block.data('id', notification.id)
      complete: ->
        button = container.find('#more-button')
        button.removeClass('disabled')
        button.html(button.data('normal'))

$ -> # messages list
  container = $('.messages .list')
  return unless container.length

  container.find('.preview').click ->
    location.href = $(this).data('href')

$ -> # messages show
  container = $('.messages .show')
  return unless container.length

  container.find('#reply-dialog').containerFormHelper({ inline: true })

  container.find('#more-button').click ->
    $(this).addClass('disabled')
    $(this).html($(this).data('loading'))
    ids = []
    container.find('.message-block').each ->
      ids.push($(this).data('id'))
    $.ajax
      url: location.href
      data:
        ajax: true
        excepted_ids: ids
      dataType: 'json'
      timeout: 5000
      success: (response) ->
        if response.is_last_page
          container.find('#more-button').remove()
        $.each response.data, (index, message) ->
          list = container.find('#message-container')
          block = container.find('.template').clone().appendTo(list)
          block.removeClass('template')
          block.removeClass('hidden')
          block.children().addClass('message-block')
          block.find('.content').html(message.content)
          block.find('.time').html(message.created_at)
          if message.from
            block.children().addClass('pull-left')
            unless message.read
              block.find('.not-read').removeClass('hidden')
          else
            block.children().addClass('pull-right')
          block.children().data('id', message.id)
      complete: ->
        button = container.find('#more-button')
        button.removeClass('disabled')
        button.html(button.data('normal'))
