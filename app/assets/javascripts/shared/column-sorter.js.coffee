$ ->
  $("body").on 'click', 'table.sortable th', ->
    header = $(this)
    index = header.index()
    inverse = header.hasClass('asc')
    header.closest('table').find('td').filter(->
      $(this).index() is index
    ).sortElements ((a, b) ->
      aImg = $(a).find('img')
      bImg = $(b).find('img')
      if $(a).find("select").length > 0
        a = $(a).find("select option:selected").text()
      else
        a = $.trim($(a).text()).substring(0,20)

      if $(b).find("select").length > 0
        b = $(b).find("select option:selected").text()
      else
        b = $.trim($(b).text()).substring(0,20)

      (if ((if isNaN(a) or isNaN(b) then a > b else +a > +b)) then (if inverse then -1 else 1) else (if inverse then 1 else -1))
    ), ->
      @parentNode
    if not header.hasClass('asc') and not header.hasClass('desc')
      $('th.asc').removeClass 'asc'
      $('th.desc').removeClass 'desc'
      header.addClass 'asc'
    else
      header.toggleClass('asc').toggleClass('desc')

jQuery.fn.sortElements = (->
  sort = [].sort
  (comparator, getSortable) ->
    getSortable = getSortable or ->
      this
    placements = @map(->
      sortElement = getSortable.call(this)
      parentNode = sortElement.parentNode
      nextSibling = parentNode.insertBefore(document.createTextNode(""), sortElement.nextSibling)
      ->
        parentNode.insertBefore this, nextSibling
        parentNode.removeChild nextSibling
    )
    sort.call(this, comparator).each (i) ->
      placements[i].call getSortable.call(this)
)()

window.clearSort = (container) ->
  # TODO: Only remove the sort image, still need to build a reset sort function
  container.find("th.asc").first().removeClass("asc")
  container.find("th.desc").first().removeClass("desc")