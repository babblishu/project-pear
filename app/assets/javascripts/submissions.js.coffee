$ -> # result
  container = $('.submissions .result')
  return unless container.length

  for id in ['compile-message', 'result', 'overall', 'source-code']
    tmp = container.find('.nav-tabs a[href="#' + id + '"]')
    if tmp.length
      tmp.tab('show')
      break