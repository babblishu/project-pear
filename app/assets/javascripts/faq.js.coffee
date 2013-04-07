$ -> # new, edit
  container = $('.faq .new, .faq .edit')
  return unless container.length

  $('#submit-button').click ->
    container.find('form').submit()

  container.find('form').ajaxForm
    dataType: 'json'
    timeout: 10000
    beforeSend: ->
      $('#submit-button').addClass('hidden')
    success: (response) ->
      if response.success
        location.href = response.redirect_url
      else
        alert(response.notice)
        $('#submit-button').removeClass('hidden')
    error: (jqXHR, textStatusm, errorThrown) ->
      alert(textStatusm) if textStatusm != null
      $('#submit-button').removeClass('hidden')
