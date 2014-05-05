###
# This File is in charge of setting up the Knockout.js viewModel for the Settlement Statement, defining any custom functions and calculations.
# Here is where all binding code takes place when tieing 2 or more input fields to each other.
###
window.ss_vm = (data) ->
  #########
  # Setup #
  #########
  ko.mapping.fromJS(data, {}, this)
  self = this

  ####################
  # KO error logging #
  ####################
  existing = ko.bindingProvider.instance
  ko.bindingProvider.instance =
    nodeHasBindings: existing.nodeHasBindings
    getBindings: (node, bindingContext) ->
      bindings = null
      try
        bindings = existing.getBindings(node, bindingContext)
      catch ex
        if console && console.log
          console.log("binding error", ex.message, node, bindingContext)
      return bindings

  #######################################################
  # Utility functions, should be moved to utility class #
  #######################################################
  addCommas = (nStr) ->
    nStr += ''
    x = nStr.split('.')
    x1 = x[0]
    x2 = (if x.length > 1 then "." + x[1] else "")
    rgx = /(\d+)(\d{3})/
    while rgx.test(x1)
      x1 = x1.replace(rgx, '$1' + ',' + '$2')
    return x1 + x2

  ########################################################
  # Binding Handlers to do custom formatting of integers #
  ########################################################
  ko.bindingHandlers.valueAsCurrency =
    init: (element, valueAccessor) ->
      observable = valueAccessor()
      formatted = ko.computed(
        read: (key) ->
          return '$' + addCommas((+observable()).toFixed(2))

        write: (value) ->
          value = parseFloat(value.replace(/[^\.\d]/g, ""))
          observable(if isNaN(value) then "" else value)
          return

        disposeWhenNodeIsRemoved: element
      )
      ko.applyBindingsToNode element, value: formatted
      return

  ko.bindingHandlers.valueAsFormatted =
    init: (element, valueAccessor) ->
      observable = valueAccessor()
      formatted = ko.computed(
        read: (key) ->
          value = addCommas((+observable()).toFixed(2))
          if value is "0.00" or value is "NaN" then return "" else return value

        write: (value) ->
          value = parseFloat(value.replace(/[^\.\d]/g, ""))
          observable(if isNaN(value) then "" else value)
          return

        disposeWhenNodeIsRemoved: element
      )
      ko.applyBindingsToNode element, value: formatted
      return

  ko.bindingHandlers.valueAsPercent =
    init: (element, valueAccessor) ->
      observable = valueAccessor()
      formatted = ko.computed(
        read: (key) ->
          value = addCommas((+observable()).toFixed(4))
          if value is "0.00" or value is "NaN" then return "" else return value + "%"

        write: (value) ->
          value = parseFloat(value.replace(/[^\.\d]/g, ""))
          observable(if isNaN(value) then "" else value)
          return

        disposeWhenNodeIsRemoved: element
      )
      ko.applyBindingsToNode element, value: formatted
      return

  ##############################
  # Tax Proration Calculations #
  ##############################
  self.proration_payee_name = (group_id, section, line, cell) ->
    payee_name = null
    ko.utils.arrayForEach self.ordered_sections(), (ss_section) ->
      if ss_section.name().toLowerCase() == "seller"
        ko.utils.arrayForEach ss_section.ordered_lines(), (ss_line) ->
          if ss_line.line_type() == "proration" && ss_line.ss_group_id() == group_id
            ko.utils.arrayForEach ss_line.ordered_cells(), (ss_cell) ->
              if ss_cell.cell_name() == "payee_name"
                payee_name = ss_cell.cell_value
    if arguments.length > 1
      if viewModel.ordered_sections()["#{section}"].name().toLowerCase() is "buyer" &&  viewModel.ordered_sections()["#{section}"].ordered_lines()["#{line}"].line_type() is "proration" && viewModel.ordered_sections()["#{section}"].ordered_lines()["#{line}"].ordered_cells()["#{cell}"].cell_name() is "payee_name"
        viewModel.ordered_sections()["#{section}"].ordered_lines()["#{line}"].ordered_cells()["#{cell}"].cell_value(payee_name()) unless payee_name() is ""
      return viewModel.ordered_sections()["#{section}"].ordered_lines()["#{line}"].ordered_cells()["#{cell}"].cell_value
    else
      return payee_name()

  self.proration = (group_id, section, line, cell) ->
    seller_start_date   = null
    seller_end_date     = null
    seller_amount       = null
    seller_credits      = null
    seller_charges      = null
    buyer_start_date    = null
    buyer_end_date      = null
    buyer_amount        = null
    buyer_credits       = null
    buyer_charges       = null
    seller_total        = null
    buyer_total         = null
    prorate             = null
    amount              = null
    other_amount        = null

    ko.utils.arrayForEach self.ordered_sections(), (ss_section) ->
      if ss_section.name().toLowerCase() == "seller"
        ko.utils.arrayForEach ss_section.ordered_lines(), (ss_line) ->
          if ss_line.ss_group_id() == group_id
            ko.utils.arrayForEach ss_line.ordered_cells(), (ss_cell) ->
              switch ss_line.line_type() + "_" + ss_cell.cell_name()
                when "proration_date_start_date" then seller_start_date = ss_cell.cell_value
                when "proration_date_end_date" then seller_end_date = ss_cell.cell_value
                when "proration_amount" then seller_amount = ss_cell.cell_value
                when "proration_credits" then seller_credits = ss_cell.cell_value
                when "proration_charges" then seller_charges = ss_cell.cell_value
      else if ss_section.name().toLowerCase() == "buyer"
        ko.utils.arrayForEach ss_section.ordered_lines(), (ss_line) ->
          if ss_line.ss_group_id() == group_id
            ko.utils.arrayForEach ss_line.ordered_cells(), (ss_cell) ->
              switch ss_line.line_type() + "_" + ss_cell.cell_name()
                when "proration_date_start_date" then buyer_start_date = ss_cell.cell_value
                when "proration_date_end_date" then buyer_end_date = ss_cell.cell_value
                when "proration_amount" then buyer_amount = ss_cell.cell_value
                when "proration_credits" then buyer_credits = ss_cell.cell_value
                when "proration_charges" then buyer_charges = ss_cell.cell_value

    ko.utils.arrayForEach self.ordered_sections(), (ss_section) ->
      if ss_section.name().toLowerCase() == self.ordered_sections()[section].name().toLowerCase()
        ko.utils.arrayForEach ss_section.ordered_lines(), (ss_line) ->
          if ss_line.ss_group_id() == group_id && ss_line.line_type() == "proration"
            ko.utils.arrayForEach ss_line.ordered_cells(), (ss_cell) ->
              if ss_cell.cell_name() == "amount"
                amount = ss_cell.cell_value
      else
        ko.utils.arrayForEach ss_section.ordered_lines(), (ss_line) ->
          if ss_line.ss_group_id() == group_id && ss_line.line_type() == "proration"
            ko.utils.arrayForEach ss_line.ordered_cells(), (ss_cell) ->
              if ss_cell.cell_name() == "amount"
                other_amount = ss_cell.cell_value

    if seller_start_date() == null || seller_end_date() == null
      return self.ordered_sections()["#{section}"].ordered_lines()["#{line}"].ordered_cells()["#{cell}"].cell_value

    switch self.tax_status()
      when "credit"
        proration_date = seller_start_date().split("/")
      when "debit"
        proration_date = seller_end_date().split("/")
      else
        proration_date = seller_end_date().split("/")

    date                = new Date(proration_date[2], Number(proration_date[0] - 1), proration_date[1])
    date_beginning_year = new Date(proration_date[2], 0, 1)
    date_end_year       = new Date(proration_date[2], 11, 31)

    other_amount(amount())
    if self.tax_total() != null
      total_days     = Math.round(12*30.4)
      proration_days = Math.abs(Math.round((date - date_beginning_year)/1000/60/60/24))
      seller_total   = ((proration_days/total_days)*amount()).toFixed(2)

      proration_days = Math.abs(Math.round((date_end_year - date)/1000/60/60/24))
      buyer_total    = ((proration_days/total_days)*amount()).toFixed(2)
      prorate        = true
    else
      prorate = false

    switch self.tax_status()
      when "credit"
        seller_start_date [date.getMonth() + 1, date.getDate(), date.getFullYear()].join("/")
        seller_end_date [date_end_year.getMonth() + 1, date_end_year.getDate(), date_end_year.getFullYear()].join("/")
        seller_charges (if prorate then "")
        seller_credits (if prorate then seller_total)
        buyer_start_date [date.getMonth() + 1, date.getDate(), date.getFullYear()].join("/")
        buyer_end_date [date_end_year.getMonth() + 1, date_end_year.getDate(), date_end_year.getFullYear()].join("/")
        buyer_charges (if prorate then seller_total)
        buyer_credits (if prorate then "")
      when "debit"
        seller_start_date [date_beginning_year.getMonth() + 1, date_beginning_year.getDate(), date_beginning_year.getFullYear()].join("/")
        seller_end_date [date.getMonth() + 1, date.getDate(), date.getFullYear()].join("/")
        seller_charges (if prorate then seller_total)
        seller_credits (if prorate then "")
        buyer_start_date [date.getMonth() + 1, date.getDate(), date.getFullYear()].join("/")
        buyer_end_date [date_end_year.getMonth() + 1, date_end_year.getDate(), date_end_year.getFullYear()].join("/")
        buyer_charges (if prorate then buyer_total)
        buyer_credits (if prorate then "")
      else
        seller_start_date [date_beginning_year.getMonth() + 1, date_beginning_year.getDate(), date_beginning_year.getFullYear()].join("/")
        seller_end_date [date.getMonth() + 1, date.getDate(), date.getFullYear()].join("/")
        seller_charges (if prorate then seller_total)
        seller_credits (if prorate then "")
        buyer_start_date [date_beginning_year.getMonth() + 1, date_beginning_year.getDate(), date_beginning_year.getFullYear()].join("/")
        buyer_end_date [date.getMonth() + 1, date.getDate(), date.getFullYear()].join("/")
        buyer_charges (if prorate then "")
        buyer_credits (if prorate then seller_total)
    return self.ordered_sections()["#{section}"].ordered_lines()["#{line}"].ordered_cells()["#{cell}"].cell_value

  self.proration_date = (group_id, section, line, cell) ->
    if self.tax_proration_date() == null
      return viewModel.ordered_sections()["#{section}"].ordered_lines()["#{line}"].ordered_cells()["#{cell}"].cell_value

    seller_start_date = null
    seller_end_date   = null
    buyer_start_date  = null
    buyer_end_date    = null
    proration_date    = self.tax_proration_date().split("-")

    ko.utils.arrayForEach self.ordered_sections(), (ss_section) ->
      if ss_section.name().toLowerCase() == "seller"
        ko.utils.arrayForEach ss_section.ordered_lines(), (ss_line) ->
          if ss_line.ss_group_id() == group_id && ss_line.line_type() == "proration_date"
            ko.utils.arrayForEach ss_line.ordered_cells(), (ss_cell) ->
              if ss_cell.cell_name() == "start_date"
                seller_start_date = ss_cell.cell_value
              else if ss_cell.cell_name() == "end_date"
                seller_end_date = ss_cell.cell_value
      else if ss_section.name().toLowerCase() == "buyer"
        ko.utils.arrayForEach ss_section.ordered_lines(), (ss_line) ->
          if ss_line.ss_group_id() == group_id && ss_line.line_type() == "proration_date"
            ko.utils.arrayForEach ss_line.ordered_cells(), (ss_cell) ->
              if ss_cell.cell_name() == "start_date"
                buyer_start_date = ss_cell.cell_value
              else if ss_cell.cell_name() == "end_date"
                buyer_end_date = ss_cell.cell_value

    if self.ordered_sections()[section].name().toLowerCase() == "seller"
      if self.tax_status() == "credit"
        buyer_start_date(seller_start_date())
        buyer_end_date("12/31/" + proration_date[0])
      else if self.tax_status() == "debit"
        seller_start_date("01/01/" + proration_date[0])
        seller_end = seller_end_date().split("/")
        buyer_start_date([seller_end[0], seller_end[1], proration_date[0]].join("/"))
        buyer_end_date("12/31/" + proration_date[0])
      else
        buyer_start_date("01/01/" + proration_date[0])
        buyer_end_date(seller_end_date())

    else if self.ordered_sections()[section].name().toLowerCase() == "buyer"
      if self.tax_status() == "credit"
        seller_start_date(buyer_start_date())
        seller_end_date("12/31/" + proration_date[0])
      else if self.tax_status() == "debit"
        seller_start_date("01/01/" + proration_date[0])
        buyer_start = buyer_start_date().split("/")
        seller_end_date([buyer_start[0], buyer_start[1], proration_date[0]].join("/"))
        buyer_end_date("12/31/" + proration_date[0])
      else
        seller_start_date("01/01/" + proration_date[0])
        seller_end_date(buyer_end_date())
    if viewModel.ordered_sections()["#{section}"].ordered_lines()["#{line}"].ordered_cells()["#{cell}"].cell_value() is not null
      return_date = viewModel.ordered_sections()["#{section}"].ordered_lines()["#{line}"].ordered_cells()["#{cell}"].cell_value().split("/")
      viewModel.ordered_sections()["#{section}"].ordered_lines()["#{line}"].ordered_cells()["#{cell}"].cell_value([return_date[0], return_date[1], proration_date[0]].join("/"))
    return viewModel.ordered_sections()["#{section}"].ordered_lines()["#{line}"].ordered_cells()["#{cell}"].cell_value

  #############################################################
  # HOA #
  #############################################################

  self.hoa_payee_name = (group_id, section, line, cell) ->
    payee_name = null
    ko.utils.arrayForEach self.ordered_sections(), (ss_section) ->
      if ss_section.name().toLowerCase() == "seller"
        ko.utils.arrayForEach ss_section.ordered_lines(), (ss_line) ->
          if ss_line.line_sub_type() == "hoa_due" && ss_line.ss_group_id() == group_id
            ko.utils.arrayForEach ss_line.ordered_cells(), (ss_cell) ->
              if ss_cell.cell_name() == "payee_name"
                payee_name = ss_cell.cell_value
    if arguments.length > 1
      if viewModel.ordered_sections()["#{section}"].name().toLowerCase() is "buyer" &&  viewModel.ordered_sections()["#{section}"].ordered_lines()["#{line}"].line_sub_type() is "hoa_due" && viewModel.ordered_sections()["#{section}"].ordered_lines()["#{line}"].ordered_cells()["#{cell}"].cell_name() is "payee_name"
        viewModel.ordered_sections()["#{section}"].ordered_lines()["#{line}"].ordered_cells()["#{cell}"].cell_value(payee_name()) unless payee_name is null ||  payee_name() is ""
      return viewModel.ordered_sections()["#{section}"].ordered_lines()["#{line}"].ordered_cells()["#{cell}"].cell_value
    else
      return payee_name()

  # Not currently bound, but could be used with in-line proration - Mark
  self.hoa_proration = (group_id, section, line, cell) ->
    if self.hoa_end_at() == "" || self.hoa_start_at() == "" || self.hoa_due() == "" || self.hoa_amount() == ""
      return self.ordered_sections()["#{section}"].ordered_lines()["#{line}"].ordered_cells()["#{cell}"].cell_value

    seller_credits      = null
    seller_charges      = null
    buyer_credits       = null
    buyer_charges       = null

    proration_date = self.hoa_end_at().split("-")
    start_date        = self.hoa_start_at().split("-")
    end_date          = self.hoa_end_at().split("-")
    hoa_amount        = self.hoa_amount()

    if self.hoa_due() == "annual"
      oneDay = 24*60*60*1000 # hours*minutes*seconds*milliseconds
      firstDate = new Date(start_date[0], start_date[1], start_date[2])
      secondDate = new Date(Number(start_date[0]) + 1, start_date[1], start_date[2])
      total_days = Math.round(Math.abs((firstDate.getTime() - secondDate.getTime())/(oneDay)))

      firstDate = new Date(start_date[0], start_date[1], start_date[2])
      secondDate = new Date(proration_date[0], proration_date[1], proration_date[2])
      prorated_days = Math.round(Math.abs((firstDate.getTime() - secondDate.getTime())/(oneDay)))

      sellers_total  = Math.round(hoa_amount * prorated_days / total_days * 100)/100
      buyers_total = hoa_amount - sellers_total
    else
      days_in_month = new Date(end_date[0], end_date[1], 0).getDate()
      sellers_total  = Math.round(hoa_amount * (Number(end_date[2]) / days_in_month)*100)/100
      buyers_total = hoa_amount - sellers_total

    switch self.hoa_applies()
      when "charge_buyer-charge_seller"
        buyer_charges = buyers_total
        seller_charges = sellers_total
        buyer_credits = ""
        seller_credits = ""
      when "charge_buyer-credit_seller"
        buyer_charges = buyers_total
        seller_charges = ""
        buyer_credits = ""
        seller_credits = buyers_total
      else
        buyer_charges = ""
        seller_charges = ""
        buyer_credits = ""
        seller_credits = ""

    if viewModel.ordered_sections()["#{section}"].ordered_lines()["#{line}"].line_sub_type() == "hoa_due"
      if viewModel.ordered_sections()["#{section}"].name().toLowerCase() == "seller"
        if viewModel.ordered_sections()["#{section}"].ordered_lines()["#{line}"].ordered_cells()["#{cell}"].cell_name() == "charges"
          viewModel.ordered_sections()["#{section}"].ordered_lines()["#{line}"].ordered_cells()["#{cell}"].cell_value( seller_charges )
        if viewModel.ordered_sections()["#{section}"].ordered_lines()["#{line}"].ordered_cells()["#{cell}"].cell_name() == "credits"
          viewModel.ordered_sections()["#{section}"].ordered_lines()["#{line}"].ordered_cells()["#{cell}"].cell_value( seller_credits )
      if viewModel.ordered_sections()["#{section}"].name().toLowerCase() == "buyer"
        if viewModel.ordered_sections()["#{section}"].ordered_lines()["#{line}"].ordered_cells()["#{cell}"].cell_name() == "charges"
          viewModel.ordered_sections()["#{section}"].ordered_lines()["#{line}"].ordered_cells()["#{cell}"].cell_value( buyer_charges )
        if viewModel.ordered_sections()["#{section}"].ordered_lines()["#{line}"].ordered_cells()["#{cell}"].cell_name() == "credits"
          viewModel.ordered_sections()["#{section}"].ordered_lines()["#{line}"].ordered_cells()["#{cell}"].cell_value( buyer_credits )
    return viewModel.ordered_sections()["#{section}"].ordered_lines()["#{line}"].ordered_cells()["#{cell}"].cell_value

  #############################################################
  # Commission inline total and the charges line of the total #
  #############################################################
  self.commission_total = (group_id, section, line, cell) ->
    sum = 0
    ko.utils.arrayForEach self.ordered_sections(), (section) ->
      ko.utils.arrayForEach section.ordered_lines(), (line) ->
        if line.ss_group_id() == group_id
          ko.utils.arrayForEach line.ordered_cells(), (cell) ->
            if cell.identifier() == "commission"
              sum += Number(cell.cell_value())
              return
    if arguments.length > 1
      viewModel.ordered_sections()["#{section}"].ordered_lines()["#{line}"].ordered_cells()["#{cell}"].cell_value(sum)
      return viewModel.ordered_sections()["#{section}"].ordered_lines()["#{line}"].ordered_cells()["#{cell}"].cell_value
    else
      return sum

  self.commission_charges = (group_id, section, line, cell) ->
    sum = 0
    ko.utils.arrayForEach self.ordered_sections(), (section) ->
      ko.utils.arrayForEach section.ordered_lines(), (line) ->
        if line.ss_group_id() == group_id
          ko.utils.arrayForEach line.ordered_cells(), (cell) ->
            if cell.identifier() == "commission"
              sum += Number(cell.cell_value())
              return
    if arguments.length > 1
      viewModel.ordered_sections()["#{section}"].ordered_lines()["#{line}"].ordered_cells()["#{cell}"].cell_value(sum)
      return viewModel.ordered_sections()["#{section}"].ordered_lines()["#{line}"].ordered_cells()["#{cell}"].cell_value
    else
      return sum

  self.commission_percent = (section, line, cell) ->
    sales_price = null
    percent = null
    commission_cell = null

    section_index = 0
    ko.utils.arrayForEach self.ordered_sections(), (ss_section) ->
      if section_index == section
        line_index = 0
        ko.utils.arrayForEach ss_section.ordered_lines(), (ss_line) ->
          if line_index == line || (ss_line.line_sub_type() == "sales_price" && ss_section.name().toLowerCase() == "seller")
            cell_index = 0
            ko.utils.arrayForEach ss_line.ordered_cells(), (ss_cell) ->
              if ss_line.line_sub_type() == "sales_price"
                if  ss_cell.cell_name() == "credits"
                  sales_price = Number(ss_cell.cell_value())
              if line_index == line
                if ss_cell.cell_name() == "percent"
                  percent = Number(ss_cell.cell_value())
                else if ss_cell.identifier() == "commission"
                  commission_cell = cell_index
              cell_index++
          line_index++
      section_index++
    if percent != null && sales_price != null && commission_cell != null && percent > 0 && sales_price > 0
      amount = Number(percent/100) * Number(sales_price)
      viewModel.ordered_sections()["#{section}"].ordered_lines()["#{line}"].ordered_cells()["#{commission_cell}"].cell_value( amount )
    return viewModel.ordered_sections()["#{section}"].ordered_lines()["#{line}"].ordered_cells()["#{cell}"].cell_value

  #############################################################
  # Downpayments #
  #############################################################
  self.downpayment = (group_id, section, line, cell) ->
    seller_amount = null
    ko.utils.arrayForEach self.ordered_sections(), (ss_section) ->
      if ss_section.name().toLowerCase() == "seller"
        ko.utils.arrayForEach ss_section.ordered_lines(), (ss_line) ->
          if ss_line.ss_group_id() == group_id && ss_line.line_sub_type() == "downpayment"
            ko.utils.arrayForEach ss_line.ordered_cells(), (ss_cell) ->
              if  ss_cell.cell_name() == "charges"
                seller_amount = ss_cell.cell_value
    if arguments.length > 1
      if viewModel.ordered_sections()["#{section}"].name().toLowerCase() is "buyer" &&  viewModel.ordered_sections()["#{section}"].ordered_lines()["#{line}"].line_sub_type() is "downpayment" && viewModel.ordered_sections()["#{section}"].ordered_lines()["#{line}"].ordered_cells()["#{cell}"].cell_name() == "credits"
        viewModel.ordered_sections()["#{section}"].ordered_lines()["#{line}"].ordered_cells()["#{cell}"].cell_value(seller_amount()) unless seller_amount() == ""
      return viewModel.ordered_sections()["#{section}"].ordered_lines()["#{line}"].ordered_cells()["#{cell}"].cell_value
    else
      return seller_amount()

  self.downpayment_payee_name = (group_id, section, line, cell) ->
    seller_value = null
    ko.utils.arrayForEach self.ordered_sections(), (ss_section) ->
      if ss_section.name().toLowerCase() == "seller"
        ko.utils.arrayForEach ss_section.ordered_lines(), (ss_line) ->
          if ss_line.ss_group_id() == group_id && ss_line.line_sub_type() == "downpayment"
            ko.utils.arrayForEach ss_line.ordered_cells(), (ss_cell) ->
              if  ss_cell.cell_name() == "payee_name"
                seller_value = ss_cell.cell_value
    if arguments.length > 1
      if viewModel.ordered_sections()["#{section}"].name().toLowerCase() is "buyer" &&  viewModel.ordered_sections()["#{section}"].ordered_lines()["#{line}"].line_sub_type() is "downpayment" && viewModel.ordered_sections()["#{section}"].ordered_lines()["#{line}"].ordered_cells()["#{cell}"].cell_name() is "payee_name"
        viewModel.ordered_sections()["#{section}"].ordered_lines()["#{line}"].ordered_cells()["#{cell}"].cell_value(seller_value()) unless seller_value() == ""
      return viewModel.ordered_sections()["#{section}"].ordered_lines()["#{line}"].ordered_cells()["#{cell}"].cell_value
    else
      return seller_value()

  self.downpayment_poc = (group_id, section, line, cell) ->
    seller_value = null
    ko.utils.arrayForEach self.ordered_sections(), (ss_section) ->
      if ss_section.name().toLowerCase() == "seller"
        ko.utils.arrayForEach ss_section.ordered_lines(), (ss_line) ->
          if ss_line.ss_group_id() == group_id && ss_line.line_sub_type() == "downpayment"
            ko.utils.arrayForEach ss_line.ordered_cells(), (ss_cell) ->
              if  ss_cell.cell_name() == "poc"
                seller_value = ss_cell.cell_value
    if arguments.length > 1
      if viewModel.ordered_sections()["#{section}"].name().toLowerCase() is "buyer" &&  viewModel.ordered_sections()["#{section}"].ordered_lines()["#{line}"].line_sub_type() is "downpayment" && viewModel.ordered_sections()["#{section}"].ordered_lines()["#{line}"].ordered_cells()["#{cell}"].cell_name() is "poc"
        if seller_value is null
          value = ""
        else
          value = seller_value().replace(/\s/g, "")
        viewModel.ordered_sections()["#{section}"].ordered_lines()["#{line}"].ordered_cells()["#{cell}"].cell_value(value) unless value == ""
      return viewModel.ordered_sections()["#{section}"].ordered_lines()["#{line}"].ordered_cells()["#{cell}"].cell_value
    else
      return seller_value()

  self.sales_price = (group_id, section, line, cell) ->
    amount = null
    ko.utils.arrayForEach self.ordered_sections(), (ss_section) ->
      if ss_section.name().toLowerCase() == "seller"
        ko.utils.arrayForEach ss_section.ordered_lines(), (ss_line) ->
          if ss_line.line_sub_type() == "sales_price" && ss_line.ss_group_id() == group_id
            ko.utils.arrayForEach ss_line.ordered_cells(), (ss_cell) ->
              if ss_cell.cell_name() == "credits"
                amount = ss_cell.cell_value
    if arguments.length > 1
      if viewModel.ordered_sections()["#{section}"].name().toLowerCase() is "buyer" &&  viewModel.ordered_sections()["#{section}"].ordered_lines()["#{line}"].line_sub_type() is "sales_price" && viewModel.ordered_sections()["#{section}"].ordered_lines()["#{line}"].ordered_cells()["#{cell}"].cell_name() is "charges"
        viewModel.ordered_sections()["#{section}"].ordered_lines()["#{line}"].ordered_cells()["#{cell}"].cell_value(amount()) unless amount() == ""
      return viewModel.ordered_sections()["#{section}"].ordered_lines()["#{line}"].ordered_cells()["#{cell}"].cell_value
    else
      return amount()

  ###############################################################
  # Sub-totals, Balance Due, Balance Due Text, and Total fields #
  ###############################################################
  self.buyer_credits_subtotal = (section, line, cell) ->
    sum = 0
    ko.utils.arrayForEach self.ordered_sections(), (section) ->
      if section.name() is "Buyer"
        ko.utils.arrayForEach section.ordered_lines(), (line) ->
          unless line.line_type() is "footer"
            ko.utils.arrayForEach line.ordered_cells(), (cell) ->
              if cell.cell_name() is "credits"
                sum += Number(cell.cell_value())
                return
    if arguments.length > 0
      viewModel.ordered_sections()["#{section}"].ordered_lines()["#{line}"].ordered_cells()["#{cell}"].cell_value(sum)
      return viewModel.ordered_sections()["#{section}"].ordered_lines()["#{line}"].ordered_cells()["#{cell}"].cell_value
    else
      return sum

  self.buyer_charges_subtotal = (section, line, cell) ->
    sum = 0
    ko.utils.arrayForEach self.ordered_sections(), (section) ->
      if section.name() is "Buyer"
        ko.utils.arrayForEach section.ordered_lines(), (line) ->
          unless line.line_type() is "footer"
            ko.utils.arrayForEach line.ordered_cells(), (cell) ->
              if cell.cell_name() is "charges"
                sum += Number(cell.cell_value())
                return
    if arguments.length > 0
      viewModel.ordered_sections()["#{section}"].ordered_lines()["#{line}"].ordered_cells()["#{cell}"].cell_value(sum)
      return viewModel.ordered_sections()["#{section}"].ordered_lines()["#{line}"].ordered_cells()["#{cell}"].cell_value
    else
      return sum

  self.buyer_credits_balance_due = (section, line, cell) ->
    total = Math.abs(self.buyer_charges_subtotal() - self.buyer_credits_subtotal())
    if arguments.length > 0
      viewModel.ordered_sections()["#{section}"].ordered_lines()["#{line}"].ordered_cells()["#{cell}"].cell_value(total)
      return viewModel.ordered_sections()["#{section}"].ordered_lines()["#{line}"].ordered_cells()["#{cell}"].cell_value
    else
      return total

  self.buyer_balance_due_text = (section, line, cell) ->
    number = self.buyer_credits_balance_due()
    if number > 0
      text = "Balance Due From Buyer(s)"
    else
      text = "Balance Due To Buyer(s)"

    viewModel.ordered_sections()["#{section}"].ordered_lines()["#{line}"].ordered_cells()["#{cell}"].cell_value(text)
    return viewModel.ordered_sections()["#{section}"].ordered_lines()["#{line}"].ordered_cells()["#{cell}"].cell_value

  self.buyer_charges_balance_due = (section, line, cell) ->
    if arguments.length > 0
      viewModel.ordered_sections()["#{section}"].ordered_lines()["#{line}"].ordered_cells()["#{cell}"].cell_value("0")
      return viewModel.ordered_sections()["#{section}"].ordered_lines()["#{line}"].ordered_cells()["#{cell}"].cell_value
    else
      return 0

  self.buyer_credits_total = (section, line, cell) ->
    total = self.buyer_credits_subtotal() + self.buyer_credits_balance_due()
    if arguments.length > 0
      viewModel.ordered_sections()["#{section}"].ordered_lines()["#{line}"].ordered_cells()["#{cell}"].cell_value(total)
      return viewModel.ordered_sections()["#{section}"].ordered_lines()["#{line}"].ordered_cells()["#{cell}"].cell_value
    else
      return total

  self.buyer_charges_total = (section, line, cell) ->
    total = self.buyer_charges_subtotal() + self.buyer_charges_balance_due()
    if arguments.length > 0
      viewModel.ordered_sections()["#{section}"].ordered_lines()["#{line}"].ordered_cells()["#{cell}"].cell_value(total)
      return viewModel.ordered_sections()["#{section}"].ordered_lines()["#{line}"].ordered_cells()["#{cell}"].cell_value
    else
      return total

  self.seller_credits_subtotal = (section, line, cell) ->
    sum = 0
    ko.utils.arrayForEach self.ordered_sections(), (section) ->
      if section.name() is "Seller"
        ko.utils.arrayForEach section.ordered_lines(), (line) ->
          unless line.line_type() is "footer"
            ko.utils.arrayForEach line.ordered_cells(), (cell) ->
              if cell.cell_name() is "credits"
                sum += Number(cell.cell_value())
                return
    if arguments.length > 0
      viewModel.ordered_sections()["#{section}"].ordered_lines()["#{line}"].ordered_cells()["#{cell}"].cell_value(sum)
      return viewModel.ordered_sections()["#{section}"].ordered_lines()["#{line}"].ordered_cells()["#{cell}"].cell_value
    else
      return sum

  self.seller_charges_subtotal = (section, line, cell) ->
    sum = 0
    ko.utils.arrayForEach self.ordered_sections(), (section) ->
      if section.name() is "Seller"
        ko.utils.arrayForEach section.ordered_lines(), (line) ->
          unless line.line_type() is "footer"
            ko.utils.arrayForEach line.ordered_cells(), (cell) ->
              if cell.cell_name() == "charges"
                sum += Number(cell.cell_value())
                return
    if isNaN(sum) then sum = ""
    if arguments.length > 0
      viewModel.ordered_sections()["#{section}"].ordered_lines()["#{line}"].ordered_cells()["#{cell}"].cell_value(sum)
      return viewModel.ordered_sections()["#{section}"].ordered_lines()["#{line}"].ordered_cells()["#{cell}"].cell_value
    else
      return sum

  self.seller_credits_balance_due = (section, line, cell) ->
    number = self.seller_credits_subtotal() - self.seller_charges_subtotal()
    if number <= 0
      number = Math.abs(number)
    else
      number = 0

    if arguments.length > 0
      viewModel.ordered_sections()["#{section}"].ordered_lines()["#{line}"].ordered_cells()["#{cell}"].cell_value(number)
      return viewModel.ordered_sections()["#{section}"].ordered_lines()["#{line}"].ordered_cells()["#{cell}"].cell_value
    else
      return number


  self.seller_balance_due_text = (section, line, cell) ->
    number = self.seller_credits_balance_due()
    if number > 0
      text = "Balance Due From Seller(s)"
    else
      text = "Balance Due To Seller(s)"

    viewModel.ordered_sections()["#{section}"].ordered_lines()["#{line}"].ordered_cells()["#{cell}"].cell_value(text)
    return viewModel.ordered_sections()["#{section}"].ordered_lines()["#{line}"].ordered_cells()["#{cell}"].cell_value

  self.seller_charges_balance_due = (section, line, cell) ->
    number = self.seller_credits_subtotal() - self.seller_charges_subtotal()
    if number < 0
      number = 0

    if arguments.length > 0
      viewModel.ordered_sections()["#{section}"].ordered_lines()["#{line}"].ordered_cells()["#{cell}"].cell_value(number)
      return viewModel.ordered_sections()["#{section}"].ordered_lines()["#{line}"].ordered_cells()["#{cell}"].cell_value
    else
      return number

  self.seller_credits_total = (section, line, cell) ->
    total = self.seller_credits_subtotal() + self.seller_credits_balance_due()
    if arguments.length > 0
      viewModel.ordered_sections()["#{section}"].ordered_lines()["#{line}"].ordered_cells()["#{cell}"].cell_value(total)
      return viewModel.ordered_sections()["#{section}"].ordered_lines()["#{line}"].ordered_cells()["#{cell}"].cell_value
    else
      return total

  self.seller_charges_total = (section, line, cell) ->
    total = self.seller_charges_subtotal() + self.seller_charges_balance_due()
    if arguments.length > 0
      viewModel.ordered_sections()["#{section}"].ordered_lines()["#{line}"].ordered_cells()["#{cell}"].cell_value(total)
      return viewModel.ordered_sections()["#{section}"].ordered_lines()["#{line}"].ordered_cells()["#{cell}"].cell_value
    else
      return total
  return

################################################################################
# Check for changes on the form and save the form data from the "ko" viewModel #
################################################################################
$(document).on "change.tru_submit", ".tru_container input[type=text]:not(.disbursement_info)", (event) ->
  form = $("#settlement_statement_form")
  ss_line_id = $(this).closest(".tru_new_line").attr("id").replace(/line_/g, "")
  json_data = ko.mapping.toJSON(viewModel)
  update_payment_windows this

  $.ajax(
    url: "/settlement_statements/" + form.data("id") + "?ss_line_id=" + ss_line_id
    data: {settlement_statement: json_data}
    dataType: "json"
    type: "put"
    timeout: 30000
    success: (data) ->
      # alert data.message
      update_payments_colors(ss_line_id, data.has_payment, data.balanced)
      refresh_disbursements()
    error: (XMLHttpRequest, textStatus, errorThrown, data) ->
      if textStatus == "timeout"
        alert "Network Timeout: Please refesh. If problem persists, please call IT."
  )
