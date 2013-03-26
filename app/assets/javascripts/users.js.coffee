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

$ -> #add_advanced_users
  container = $('.users .add_advanced_users')
  return unless container.length

  container.find('#user-search').typeahead
    minLength: 2
    source: (query, process) ->
      $.ajax
        url: '/search_user'
        data:
          ajax: true
          add_advanced_users_auto_complete: true
          handle: query
        dataType: 'json'
        timeout: 1000
        success: (response) ->
          process(response)

  add_users_form = container.find('#add-users')
  submit_button = container.find('#submit-button')
  users_table = container.find('#users-table')

  add_users_form.ajaxForm
    dataType: 'json'
    timeout: 1000
    data:
      ajax: true
      add_advanced_users: true
    beforeSend: ->
      add_users_form.find('input').prop('disabled', true)
    success: (response) ->
      if response.success
        flag = false
        users_table.find('tr').each ->
          flag = true if $(this).data('handle') == response.handle
        unless flag
          block = users_table.find('.template').clone().appendTo(users_table)
          block.removeClass('template')
          block.removeClass('hidden')
          block.data('handle', response.handle)
          block.find('td.handle').html(response.handle)
          block.find('td.real-name').html(response.real_name)
          block.find('td.school').html(response.school)
          submit_button.removeClass('hidden')
          block.find('td button.cancel').click ->
            if confirm('Remove ' + $(this).parents('tr').find('td.handle').text() + '?')
              $(this).parents('tr').remove()
              submit_button.addClass('hidden') if users_table.find('tbody tr').length == 1
      else
        alert(response.notice)
    complete: ->
      add_users_form.find('input').prop('disabled', false)
      add_users_form.find('input').val('')

  submit_button.click ->
    handles = []
    users_table.find('tbody tr').each ->
      handles.push($(this).data('handle')) unless $(this).hasClass('hidden')
    $.ajax
      url: '/users/admin_advanced_users/add'
      dataType: 'json'
      timeout: 10000
      type: 'POST'
      data:
        handles: handles
      beforeSend: ->
        submit_button.addClass('disabled')
      success: (response) ->
        alert(response.notice)
        if response.success
          location.href = response.redirect_url
      complete: ->
        submit_button.removeClass('disabled')

