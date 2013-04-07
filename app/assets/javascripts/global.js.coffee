$.fn.formErrorHelper = ->
  this.find('input, textarea').change ->
    control_group = $(this).parents('.control-group')
    control_group.removeClass('error')
    control_group.find('.help-inline').html('')

$.fn.programLanguageSelectHelper = ->
  form = this
  unless form.find('input.language:checked').length
    language = form.find('input.language').first().attr('value')
    form.find('input.language.' + language).prop('checked', true)
  form.find('input.program').change ->
    ext = $(this).val().split('.').pop()
    form.find('input.language.' + ext).prop('checked', true)

$.fn.disableButton = ->
  this.addClass('disabled')
  text = this.data('disabled')
  if text and text.length
    this.data('normal', this.html())
    this.html(text)

$.fn.enableButton = ->
  this.removeClass('disabled')
  text = this.data('normal')
  this.html(text) if text and text.length

$.fn.focusEnd = ->
  text = this.val()
  this.focus().val('').val(text)

$.fn.setErrorState = (errors) ->
  form = this
  form.find('.help-inline').html('')
  form.find('.error').removeClass('error')
  $.each errors, (key, value) ->
    if Array.isArray(value)
      $.each value, (index, x) ->
        form.find('.help-inline[data-errors~="' + key + '"]').append('<span>' + x + '</span>')
    else
      form.find('.help-inline[data-errors~="' + key + '"]').append('<span>' + value + '</span>')
  form.find('.help-inline').each ->
    if $(this).html().search(/\S/) != -1 then $(this).parents('.control-group').addClass('error')
  if form.find('.nav-pills').length
    tmp = form.find('.error').first()
    pill_id = tmp.parents('.pill-pane').prop('id')
    form.find('.nav-pills a[href="#' + pill_id + '"]').tab('show')
    tmp.find('input[type=text], input[type=password], input[type=email], textarea').first().focusEnd()
  else
    form.find('.error input[type=text], .error input[type=password], .error input[type=email], .error textarea').first().focusEnd()

$.fn.formSubmitHelper = (container, button) ->
  form = this
  form.formErrorHelper()
  container = form unless container
  button = form.find('button[type=submit]') unless button
  form.ajaxForm
    dataType: 'json'
    timeout: 10000
    beforeSend: ->
      button.disableButton()
    success: (response) ->
      if response.success
        if response.notice and response.notice.length
          alert(response.notice)
        if response.redirect_url
          location.href = response.redirect_url
        else
          location.reload(true)
      else
        if response.notice and response.notice.length
          alert(response.notice)
        form.find('input[type=password]').val('')
        if response.errors
          form.setErrorState(response.errors)
        button.enableButton()
    error: (jqXHR, textStatusm, errorThrown) ->
      alert(textStatusm) if textStatusm != null
      button.enableButton()

$.fn.inlineFormSubmitHelper = (container, button) ->
  form = this
  container = form unless container
  button = container.find('button[type=submit]') unless button
  form.ajaxForm
    dataType: 'json'
    timeout: 10000
    beforeSend: ->
      button.disableButton()
    success: (response) ->
      if response.success
        if response.notice and response.notice.length
          alert(response.notice)
        if response.redirect_url
          location.href = response.redirect_url
        else
          location.reload(true)
      else
        if response.notice and response.notice.length
          alert(response.notice)
        form.find('input[type=password]').val('')
        if response.error
          if container.find('.text-error').length
            container.find('.text-error').html(response.error)
          else
            alert(response.error)
        button.enableButton()
    error: (jqXHR, textStatusm, errorThrown) ->
      alert(textStatusm) if textStatusm != null
      button.enableButton()

$.fn.containerFormHelper = (options) ->
  form = options['form']
  form = this.find('form').first() unless form
  button = options['button']
  button = this.find('button[type=submit]').first() unless button
  if options['inline']
    form.inlineFormSubmitHelper(this, button)
  else
    form.formSubmitHelper(this, button)
  button.click ->
    form.submit()

$.parseJSONDiv = (name) ->
  $.parseJSON($('div.json[data-name="' + name + '"]').first().html())

$.ratioStr = (a, b) ->
  b = 1 if b == 0
  Math.round(a * 100 / b) + '%'

$ -> # home
  container = $('.global .home')
  return unless container.length

  search_url = container.find('#user-search').data('search-url')
  container.find('#user-search').typeahead
    minLength: 2
    source: (query, process) ->
      $.ajax
        url: search_url
        data:
          ajax: true
          handle: query
        dataType: 'json'
        timeout: 1000
        success: (response) ->
          process(response)

$ -> # captcha_verify
  container = $('.global .captcha_verify')
  return unless container.length

  captcha_url = container.find('#captcha').prop('src')
  container.find('#captcha').click ->
    $(this).prop('src', captcha_url + '&t=' + new Date().getTime())

$ ->
  $('#login-dropdown form').inlineFormSubmitHelper()

  toolbar = $('#toolbar')
  if toolbar.length
    toolbar.insertAfter('#main-nav')
    toolbar.removeClass('hidden')

  page_config = $('#page-config')
  if page_config.length
    page_title = page_config.find('.title')
    if page_title.length
      oj_name = $('head title').html()
      $('head title').html(page_title.html() + ' - ' + oj_name)

    navbar = $('#main-nav')
    navbar.children('li').each ->
      tmp = page_config.find('.' + $(this).data('name') + '-active')
      if tmp.length && tmp.html() == 'true'
        $(this).addClass('active')
