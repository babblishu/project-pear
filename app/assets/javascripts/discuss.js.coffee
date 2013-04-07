$ -> # edit_content_dialog
  container = $('.discuss')
  return unless container.length

  container.find('.edit-content-dialog').each ->
    $(this).containerFormHelper({})
    $(this).find('.nav-pills a').first().tab('show')
    form = $(this).find('form')
    form.programLanguageSelectHelper()
    form.find("a[data-toggle='tooltip']").tooltip()

$ -> # show
  container = $('.discuss .show')
  return unless container.length

  blocked_users = $.parseJSONDiv('blocked_users')
  medium_avatar_urls = $.parseJSONDiv('medium_avatar_urls')
  container.find('.primary-block').each ->
    avatar = $(this).find('.user-avatar')
    handle = $(this).data('owner')
    if $.inArray(handle, blocked_users) == -1
      avatar.find('a').html('<img src="' + medium_avatar_urls[handle] + '">')
    else
      avatar.html('<img src="/img/blocked_user_medium.png">')
  thumb_avatar_urls = $.parseJSONDiv('thumb_avatar_urls')
  container.find('.secondary-block').each ->
    avatar = $(this).find('.user-avatar')
    handle = $(this).data('owner')
    if $.inArray(handle, blocked_users) == -1
      avatar.find('a').html('<img src="' + thumb_avatar_urls[handle] + '">')
    else
      avatar.html('<img src="/img/blocked_user_thumb.png">')

  current_user = $.parseJSONDiv('current_user')
  container.find('.block').each ->
    block = $(this)
    owner = block.data('owner')
    if owner == current_user.handle || current_user.role == 'admin'
      block.find('.edit-button').removeClass('hidden')

  container.find('button.button-link').click ->
    if confirm($(this).data('confirm'))
      $(this).addClass('disabled')
      location.href = $(this).data('href')

  container.find('.inline-edit.operations').each ->
    block = $(this)

    if $(this).find('.reply').length
      block.containerFormHelper
        form: block.find('.reply-area form')
        button: block.find('.submit-reply')
        inline: true

    if $(this).find('.edit').length
      block.containerFormHelper
        form: block.find('.edit-area form')
        button: block.find('.submit-edit')
        inline: true

    $(this).find('.reply').click ->
      block.find('.cancel-reply').removeClass('hidden')
      block.find('.submit-reply').removeClass('hidden')
      block.find('.reply-area').removeClass('hidden')
      $(this).addClass('hidden')
      block.find('.edit').addClass('hidden')
      block.find('.reply-area textarea').focusEnd()

    $(this).find('.cancel-reply').click ->
      $(this).addClass('hidden')
      block.find('.submit-reply').addClass('hidden')
      block.find('.reply-area').addClass('hidden')
      block.find('.reply').removeClass('hidden')
      block.find('.edit').removeClass('hidden')

    $(this).find('.edit').click ->
      block.find('.cancel-edit').removeClass('hidden')
      block.find('.submit-edit').removeClass('hidden')
      block.find('.edit-area').removeClass('hidden')
      $(this).addClass('hidden')
      block.find('.reply').addClass('hidden')
      block.find('.edit-area textarea').focusEnd()

    $(this).find('.cancel-edit').click ->
      $(this).addClass('hidden')
      block.find('.submit-edit').addClass('hidden')
      block.find('.edit-area').addClass('hidden')
      block.find('.edit').removeClass('hidden')
      block.find('.reply').removeClass('hidden')
