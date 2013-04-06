$ -> # show
  container = $('.problems .show')
  return unless container.length

  container.find('#upload-test-data-dialog button[type=submit]').click ->
    $(this).disableButton()
    container.find('#upload-test-data-dialog form').submit()

  program_submit_dialog = container.find('#program-submit-dialog')
  program_submit_form = program_submit_dialog.find('form')

  language = $.cookie('language') ? program_submit_form.find("input[name='language']").first().attr('value')
  platform = $.cookie('platform') ? program_submit_form.find("input[name='platform']").first().attr('value')
  program_submit_form.find("input[name='language'][value='" + language + "']").prop('checked', true)
  program_submit_form.find("input[name='platform'][value='" + platform + "']").prop('checked', true)

  program_submit_form.find("input[name='program']").change ->
    ext = $(this).val().split('.').pop()
    program_submit_form.find("input[name='language'][value='" + ext + "']").prop('checked', true)

  program_submit_form.formErrorHelper()
  program_submit_form.ajaxForm
    dataType: 'json'
    timeout: 10000
    beforeSend: ->
      $.cookie('language', program_submit_form.find("input[name='language']:checked").val(), { expires: 365, path: '/' })
      $.cookie('platform', program_submit_form.find("input[name='platform']:checked").val(), { expires: 365, path: '/' })
      program_submit_dialog.find('button[type=submit]').disableButton()
    success: (response) ->
      if response.success
        program_submit_dialog.find('button[type=submit]').enableButton()
        program_submit_dialog.modal('hide')
        location.href = response.redirect_url
      else
        if response.notice and response.notice.length
          alert(response.notice)
        if response.errors
          program_submit_form.setErrorState(response.errors)
        program_submit_dialog.find('button[type=submit]').enableButton()
    error: (jqXHR, textStatusm, errorThrown) ->
      alert(textStatusm) if textStatusm != null
      program_submit_dialog.find('button[type=submit]').enableButton()

  program_submit_dialog.find('button[type=submit]').click ->
    program_submit_form.submit()

$ -> # list
  container = $('.problems .list')
  return unless container.length

  problems_list = container.find('#problems-list')

  problems_stat = $.parseJSONDiv('problems_stat')
  for item in problems_stat
    row = problems_list.find('tr[data-id=' + item[0] + ']')
    row.find('td.accepted-submissions a').html(item[1])
    row.find('td.attempted-submissions a').html(item[2])
    row.find('td.ratio').html($.ratioStr(item[1], item[2]))

  if container.find('div.json[data-name="accepted_problem_ids"]').length
    accepted_problem_ids = $.parseJSONDiv('accepted_problem_ids')
    attempted_problem_ids = $.parseJSONDiv('attempted_problem_ids')
    for item in accepted_problem_ids
      row = problems_list.find('tr[data-id=' + item + ']')
      row.find('td.icon .accepted').removeClass('hidden')
    for item in attempted_problem_ids
      row = problems_list.find('tr[data-id=' + item + ']')
      if row.find('td.icon .accepted').hasClass('hidden')
        row.find('td.icon .unaccepted').removeClass('hidden')

  problems_list.find('th.sortable').click (event) ->
    event.stopPropagation()
    thIndex = $(this).index()
    inverse = $(this).hasClass('asc')
    problems_list.find('th.sortable').removeClass('asc desc')
    if inverse
      $(this).addClass('desc')
    else
      $(this).addClass('asc')
    problems_list.find('td').filter ->
      $(this).index() == thIndex
    .sortElements (a, b) ->
      x = parseInt($.text([a]))
      y = parseInt($.text([b]))
      if x < y
        res = -1
      if x == y
        res = 0
      if x > y
        res = 1
      if inverse
        res *= -1
      res
    , ->
      this.parentNode

  container.find('#new-problem-dialog').containerFormHelper({})

  filter_dialog = container.find('#filter-dialog')
  filter_form = container.find('#filter-form')
  tag_ids = $.parseJSONDiv('tag_ids')
  for id in tag_ids
    filter_form.find('input[type=checkbox][name="tag_' + id + '"]').prop('checked', true)

  filter_dialog.find("button[data-toggle='tooltip']").tooltip()
  filter_dialog.find('button.submit').click ->
    if filter_form.find('input:checked').length > 5
      alert(filter_form.find('#alert-message').text())
      return
    filter_form.submit()

$ -> # edit
  container = $('.problems .edit')
  return unless container.length

  form = container.find('#problem-edit-form')
  form.programLanguageSelectHelper()
  form.formErrorHelper()
  need_confirm = false
  form.find('input, textarea').change ->
    need_confirm = true
  $('#submit-button').click ->
    need_confirm = false
    form.submit()
  window.onbeforeunload = ->
    return container.find('#confirm-message').text() if need_confirm
  form.ajaxForm
    dataType: 'json'
    beforeSend: ->
      $('#submit-button').disableButton()
    success: (response) ->
      if response.success
        location.href = response.redirect_url
      else
        form.setErrorState(response.errors)
        tmp = form.find('.error').first()
        tab_id = tmp.parents('.tab-pane').prop('id')
        form.find('.nav-tabs a[href="#' + tab_id + '"]').tab('show')
        tmp.find('input[type=text], textarea').first().focusEnd()
        $('#submit-button').enableButton()
        need_confirm = true
    error: (jqXHR, textStatusm, errorThrown) ->
      alert(textStatusm) if textStatusm != null
      $('#submit-button').enableButton()

$ -> # upload_test_data
  container = $('.problems .upload_test_data')
  return unless container.length

  container.find('#upload-test-data-dialog button[type=submit]').click ->
    $(this).disableButton()
    container.find('#upload-test-data-dialog form').submit()
