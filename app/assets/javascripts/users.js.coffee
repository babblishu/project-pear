$ -> # register
  container = $('.users .register')
  return unless container.length

  register_form = container.find('form')
  register_form.find("a[data-toggle='tooltip']").tooltip()
  register_form.formErrorHelper()
  captcha_url = register_form.find('#captcha').prop('src')
  register_form.find('#captcha').click ->
    $(this).prop('src', captcha_url + '&t=' + new Date().getTime())
  register_form.ajaxForm
    dataType: 'json'
    timeout: 10000
    beforeSend: ->
      register_form.find('button[type=submit]').disableButton()
    success: (response) ->
      if response.success
        alert(response.notice)
        location.href = response.redirect_url
      else
        register_form.find('input[type=password]').val('')
        register_form.find('#captcha-input').val('')
        register_form.find('#captcha').prop('src', captcha_url + '&t=' + new Date().getTime())
        register_form.setErrorState(response.errors)
        register_form.find('button[type=submit]').enableButton()

$ -> #edit
  container = $('.users .edit')
  return unless container.length

  edit_form = container.find('form')
  edit_form.formSubmitHelper()
  edit_form.find("a[data-toggle='tooltip']").tooltip()

$ -> # edit_password
  container = $('.users .edit_password')
  return unless container.length

  container.find('form').formSubmitHelper()

$ -> #show
  container = $('.users .show')
  return unless container.length

  container.find('#upto-advanced-user-dialog').containerFormHelper({})
  container.find('#upto-admin-dialog').containerFormHelper({})
  container.find('#block-user-dialog').containerFormHelper({})
  container.find('#unblock-user-dialog').containerFormHelper({})
  container.find('#message-dialog').containerFormHelper({ inline: true })
