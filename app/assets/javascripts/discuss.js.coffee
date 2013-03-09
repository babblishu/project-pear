$ -> # edit_content_dialog
  container = $('.discuss')
  return unless container.length

  container.find('.edit-content-dialog').each ->
    $(this).containerFormHelper({})
    form = $(this).find('form')
    form.programLanguageSelectHelper()
    form.find("a[data-toggle='tooltip']").tooltip()

$ -> # show
  container = $('.discuss .show')
  return unless container.length

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
