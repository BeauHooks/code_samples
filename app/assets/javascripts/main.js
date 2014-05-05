var active_row;
var request = "GET";

$.ajaxSetup({
  headers: {
    'X-CSRF-Token': $('meta[name="csrf-token"]').attr('content')
  }
});

$(document).ready(function(){
  var $appeared = $('#appeared');
  // HTML reload flash messages (Not AJAX Flash)
  $('.flash').delay(500).fadeIn('normal', function() {
    $(this).delay(4000).fadeOut();
  });

  // Remove for red x
  $(document).on("click", ".remove_row", function(event){
    $(this).closest("tr").remove();
  });

  // $(document).on("DOMNodeInserted", ".auto_select", function(event){
  //   $(this).select2();
  // });

  // Bind JqueryUI Elements
  $("#tabs").tabs();
  $(document).on("focus", ".datepicker", function(event){
    $(".datepicker").datepicker({
      changeMonth: true
    });
  });

  // Click and drag for overlays
  $("body").on("mouseover", ".draggable", function(){
    $(this).draggable({ cancel: ".overlay_content" });
  });
  $("body").on("mousedown", ".draggable", function(){
    $("div.draggable").removeClass("bring_to_front");
    $(this).toggleClass("bring_to_front");
  });

  bind_data_update();
});

$(document).ajaxComplete(function(event, request) {
  var msg = request.getResponseHeader('X-Message');
  var type = request.getResponseHeader('X-Message-Type');
  if(type == "notice" || type == "error" || type == "alert"){
    show_ajax_message(msg, type);
  }
});

var fade_flash = function() {
  $(".flash").delay(6000).fadeOut("slow");
}

var show_ajax_message = function(msg, type) {
  $("html").scrollTop(0);
  $("#flash-message").html('<div id="'+type+'" class="flash">'+msg+'</div>');
  fade_flash();
}

// Store current keypress in a global variable
$(document).keypress(function(event){
  window.keycode = (event.keyCode ? event.keyCode : event.which);
});

function sanitize_phone(number){
  var num = String(number);
  num = num.replace(/\+/g,'');
  num = num.replace(/\(/g,'');
  num = num.replace(/\)/g,'');
  num = num.replace(/\s/g,'');
  num = num.replace(/-/g,'');
  num = num.replace("Cell:","");
  num = num.replace("Work:","");
  return num;
}

//
// Main initializer for application-wide functionality
// Call this whenever adding elements to the view
//

function initializer() {
  formatFax();
  formatPhone();

  $(".grid_header td").unbind('.sortResults');

  $(".grid_header td").bind('click.sortResults', function(){
    sortResults(this);
  });

    // Sets up inputs and textareas so they can be escaped and retain their value
   $(" input:text ").unbind('focus.escape').bind('focus.escape', function() {
      this.setAttribute("data-escape", $(this).val().replace(/'/g, "\'").replace(/"/g, '\"') );
   });

   $(" input:text ").unbind('blur.empty').bind('blur.empty', function() {
      $(this).val( $(this).val().replace(/'/g, "\'").replace(/"/g, '\"') + "" );
   });

   $(" input:text ").unbind('keydown.escape').bind('keydown.escape', function(event) {
      if(event.keyCode == 27){
        this.value = this.getAttribute("data-escape").replace(/'/g, "\'").replace(/"/g, '\"') ;
        $(this).blur();
      }
   });

   $(" textarea ").unbind('focus.textescape').bind('focus.textescape', function() {
      this.setAttribute("data-escape", $(this).val().replace(/'/g, "\'").replace(/"/g, '\"') );
   });

   $(" textarea ").unbind('blur.textempty').bind('blur.textempty', function() {
      $(this).val( $(this).val().replace(/'/g, "\'").replace(/"/g, '\"') );
   });

   $(" textarea ").unbind('keydown.textescape').bind('keydown.textescape', function(event) {
      if(event.keyCode == 27){
        this.value = this.getAttribute("data-escape").replace(/'/g, "\'").replace(/"/g, '\"') ;
        $(this).blur();
      }
   });

   $(" div[contenteditable='true'] ").unbind('focus.textescape').bind('focus.textescape', function() {
      this.setAttribute("data-escape", $(this).html().replace(/'/g, "\'").replace(/"/g, '\"') );
   });

   $(" div[contenteditable='true'] ").unbind('blur.textempty').bind('blur.textempty', function() {
      $(this).html( $(this).html().replace(/'/g, "\'").replace(/"/g, '\"') );
   });

   $(" div[contenteditable='true'] ").unbind('keydown.textescape').bind('keydown.textescape', function(event) {
      if(event.keyCode == 27){
        this.innerHTML = this.getAttribute("data-escape").replace(/'/g, "\'").replace(/"/g, '\"') ;
        $(this).blur();
      }
   });

   // Sets up images to blur so they don't have the border when clicked
   $(" img ").unbind('focus.imageblur').bind('focus.imageblur', function() {
      $(this).blur();
   });

   $(" img ").unbind('click.imageblur').bind('click.imageblur', function() {
      $(this).blur();
   });

   $("tr").unbind('.navigation').bind('click.navigation', function() {
    if($(this).attr('class') != undefined && $(this).attr('class').indexOf('trigger') != -1){
      active_row = $(this);
      $("body").unbind('.keydown_navigation')
      $("body").bind('keydown.keydown_navigation', function(event){
        var code = event.which;
        if($(active_row).attr('class') != undefined && $(active_row).attr('class').indexOf('active_row') != -1 ){
          if(code == 38 || code == 40){
            container = $(active_row).closest('.results');
            index = code == 38 ? $(container).find('tr').index(active_row) - 1 : $(container).find('tr').index(active_row) + 1;
            if(index >= 0 && index < $(container).find('tr').length){
              new_active_row = $(container).find('tr').eq(index);
              $(new_active_row).click();
              $(container).animate({ scrollTop: $(new_active_row).offset().top - $(container).offset().top + $(container).scrollTop() }, 100);
            }
          }
        }
      });
    }
  });
}

function escapeHtml(string) {
  var entityMap = {
    "&": "%26",
    "<": "%3C",
    ">": "%3E",
    '"': '%22',
    "'": '%27',
    "/": '%2F',
    "#": '%23'
  };
  return String(string).replace(/[#&<>"'\/]/g, function (s) {
    return entityMap[s];
  });
}

function bind_data_update(){
  $("table[data-update='true']").on("change","input, select", function(event){
    var data_url = $(this).parents("tr:first").data("url");
    var field = $(this).attr("name");
    var value = escapeHtml($(this).val());
    var param = "&" + field + "=" + value;
    $.ajaxq("data-update",{
      url: data_url + param,
      type: "PUT"
    });
  });
}

function makeId(){
  var text = "";
  var possible = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789";

  for( var i=0; i < 5; i++ )
      text += possible.charAt(Math.floor(Math.random() * possible.length));

  return text;
}

function formatDatetime(timestamp) {
  var date = new Date((timestamp || "").replace(/-/g,"/").replace(/[TZ]/g," "));
  var cur_month = date.getMonth();
  var cur_day = date.getDate();
  var cur_year = date.getFullYear();
  return cur_month + '/' + cur_day + '/' + cur_year;
}

function formatCurrency(num) {
  // Replace everything that is not a number or decimal point
  // Function was returning 0.00 if any characters existed.
  // This now returns amount without additional characters.
  num = num.toString().replace(/[^0-9.]/g, '');
  if (isNaN(num)) num = "0";
  sign = (num == (num = Math.abs(num)));
  num = Math.floor(num * 100 + 0.50000000001);
  cents = num % 100;
  num = Math.floor(num / 100).toString();
  if (cents < 10) cents = "0" + cents;
  for (var i = 0; i < Math.floor((num.length - (1 + i)) / 3); i++)
  num = num.substring(0, num.length - (4 * i + 3)) + ',' + num.substring(num.length - (4 * i + 3));
  return (((sign) ? '' : '-') + '$' + num + '.' + cents);
}

function formatFax() {
  $("td.fax").text(function(i, text) {
    text = text.replace(/(\d\d\d)(\d\d\d)(\d\d\d\d)/, "$1-$2-$3");
    return text;
  });
}

function formatPhone() {
  $("td.phone a").text(function(i, text) {
    text = text.replace(/(\d\d\d)(\d\d\d)(\d\d\d\d)/, "$1-$2-$3");
    return text;
  });
}

function sortResults(object){
  var results = $(object).closest('.box').find('.results').eq(0).find('table');
  if($(results).length == 0 || $(object).find('input[type=checkbox]').length > 0 || $(object).hasClass("no_sort") ){
    return;
  }
  var current = $(results).find('tr').length;
  var index = $(object).index();
  var asc = $(object).closest('tr').find('td.sort_asc');
  var desc = $(object).closest('tr').find('td.sort_desc');
  var prev = "";
  var sort = "";
  var swaps = 0;
  var reverse = false;

  if($(asc).index() == index){
    $(object).removeClass('sort_asc');
    $(object).addClass('sort_desc');
    $(object).find('img.sort_img').remove();
    $(object).html($(object).html() + "<img src='assets/down.png' style='width: 10px; position: relative; top: 1px; left: 2px;' class='sort_img' />");
    sort = "desc";
    reverse = true;
  }
  else if($(desc).index() == index){
    $(object).removeClass('sort_desc');
    $(object).addClass('sort_asc');
    $(object).find('img.sort_img').remove();
    $(object).html($(object).html() + "<img src='assets/up.png' style='width: 10px; position: relative; top: 1px; left: 2px;' class='sort_img' />");
    sort = "asc";
    reverse = true;
  }
  else{
    if($(asc).index() != -1){
      $(asc).removeClass('sort_asc');
      $(asc).find('img.sort_img').remove();
    }

    if($(desc).index() != -1){
      $(desc).removeClass('sort_desc');
      $(desc).find('img.sort_img').remove();
    }

    $(object).addClass('sort_asc');
    $(object).html($(object).html() + "<img src='assets/up.png' style='width: 10px; position: relative; top: 1px; left: 2px;' class='sort_img' />");
    sort = "asc";
  }

  if($(results).find('.preview').length > 0){
    $(results).find('.active_row').removeClass('active_row');
    $(results).find('.preview').each(function(){
      $(this).html('');
      $(this).remove();
    });
  }

  results = $(object).closest('.box').find('.results').eq(0).find('table');

  if(reverse){
    $(results).find('tr:not(.preview)').each(function(){
      $(results).prepend($(this));
    });
  }
  else{

    prev_td = $(results).find('tr').eq(0).find('td').eq(index);
    if( $(prev_td).find('select').length > 0 ){
      type = "select";
    }
    else if( $(prev_td).find('input[type=text]').length > 0 ){
      type = "input";
    }
    else if( $(prev_td).find('input[type=button]').length > 0 ){
      type = "button";
    }
    else if($(prev_td).find('input[type=checkbox]').length > 0){
      type = "checkbox";
    }
    else{
      type = "standard";
    }

    is_number = false;
    while(current > 0){
      prev = "";
      i = 0;
      $(results).find('tr').slice(0, current).each(function(){
        if(prev == ""){
          // do nothing
        }
        else{
          switch(type)
          {
          case "select":
            this_value = $(this).find('td').eq(index).find('select').find(':selected').text();
            prev_value = $(prev).find('td').eq(index).find('select').find(':selected').text();
            break;
          case "input":
            this_value = $(this).find('td').eq(index).find('input[type=text]').val();
            prev_value = $(prev).find('td').eq(index).find('input[type=text]').val();
            break;
          case "button":
            try{
              this_value = $(this).find('td').eq(index).find('input[type=button]').data("added");
              prev_value = $(prev).find('td').eq(index).find('input[type=button]').data("added");
            }
            catch(error){
              clearSorting($(object).closest('.box').attr('id'));
              return false;
            }
            break;
          case "checkbox":
            $(this).find('td').eq(index).find('input[type=checkbox]').attr('checked') == 'checked' ? this_value = 1 : this_value = 0;
            $(prev).find('td').eq(index).find('input[type=checkbox]').attr('checked') == 'checked' ? prev_value = 1 : prev_value = 0;
            break;
          default:
            this_value = $(this).find('td').eq(index).text().replace("$", "").replace(",", "");
            prev_value = $(prev).find('td').eq(index).text().replace("$", "").replace(",", "");
          }

          if( (type != "checkbox" && !isNaN(parseFloat(this_value)) && !isNaN(parseFloat(prev_value)) && isFinite(this_value) && isFinite(prev_value)) || is_number ){
            this_value = Number(this_value);
            prev_value = Number(prev_value);
            is_number = true;
          }

          if(sort == "asc"){
            if(this_value < prev_value){
              $(prev).before($(this));
            }
          }
          else{
            if(this_value > prev_value){
              $(prev).before($(this));
            }
          }
        }
        prev = $(results).find('tr').eq(i);
        i += 1;
      });
      current -= 1;
    }
  }
}

function clearSorting(container_reference){
  $(container_reference + ' .sort_asc').find('img.sort_img').remove();
  $(container_reference + ' .sort_asc').removeClass('sort_asc');
  $(container_reference + ' .sort_desc').find('img.sort_img').remove();
  $(container_reference + ' .sort_desc').removeClass('sort_desc');
}

//Add any post action to ajax queue
function addToQueue(title, post, request){
  $.ajaxq(title,{
    url: post,
    type: request
  });
  return true;
}

// Checkbox functionality that allows for select/deselect all
function selectAll(object, list){
  var list = list || "nothing";
  if(list == "nothing"){
    list = $(object).closest("table").find("tbody").first();
    $(list).find("td.select input[type=checkbox]").each(function(){
      if(object.checked && this.disabled != true){
        $(this).prop("checked", true);
      }
      else{
        $(this).prop("checked", false);
      }
    });
  }
  else{
    $("#" + list + " input[type=checkbox]").each(function(){
      if($(object).prop("checked") && this.disabled != true){
        $(this).prop("checked", true);
      }
      else{
        $(this).prop("checked", false);
      }
    });
  }
}

function selectIndividual(object){
  $(object).closest('div').find('input[type=checkbox]').each(function(){
    $(this).prop('checked', true);
  });

  $(object).prop("checked", true);
}

// Gets selected items from container
function getSelected(object){
  var boxes = $(object).closest('div.box').find('div.results').find('td.select input[type=checkbox]');
  var list = "";

  $(boxes).each(function(){
    if($(this).prop("checked")){
      list += "&list[]=" + $(this).data('id');
    }
  });
  return list;
}


function stuff(hud_line_id) {
  $.ajaxq("stuff",{
    url: "/hud_lines/" + hud_line_id + "/view_check",
    type: "post"
  });
}

function displayCompanyList(){
  var options = document.getElementById("company_options");
  options.className = options.className.replace("hidden", "");
  options.className = "visible";
}

function hideCompanyList(){
  var options = document.getElementById("company_options");
  options.className = options.className.replace("visible", "");
  options.className = "hidden";
}

function changeMe(id, type, value){
  var inside = "";

  if (type == 'text'){
    inside =  "<input type='text' value='" + value + "' onblur='changeBack(" + '"' + id +  '"' + ", " + '"' +  type  + '"' + " )' />";
  }

  document.getElementById(id).innerHTML = inside;
}

function changeBack(id, type){
  var value = document.getElementById(id).value;

  documen.getElementById(id).innerHTML = "<p onclick='changeMe('" + id + "', '" + type + "', '" + value + "')'>" + value + "</p>";
}

// These functions fix the width of the header of a scrollable table when scroll is visible or not
// Use an id that ends with "_last" on the last column of the header to resize it.
function addWidth(box, width){
  var id = box + '_last';
  var current = document.getElementById(id).style.width.replace("px", "") ;

  if(current <= width){
    width += 16;
    newWidth = width + 'px';
    document.getElementById(id).style.width = newWidth;
  }
}

function fixWidth(box, width){
  var id = box + '_last';
  var current = document.getElementById(id).offsetWidth;

  if(current > width){
    newWidth = width + 'px';
    document.getElementById(id).style.width = newWidth;
  }
}

function fixLoadingHeight(left, right){
  var overviewLeft = document.getElementById(left).offsetHeight;
  var overviewRight = document.getElementById(right).offsetHeight;

  if(overviewLeft >= overviewRight){
    document.getElementById("loading_cover").style.height = overviewLeft + "px";
  }
  else{
    document.getElementById("loading_cover").style.height = overviewRight + "px";
  }
}

function showHint(id){
  document.getElementById(id).getElementsByTagName("span")[0].style.display = "";
}

function hideHint(id){
  document.getElementById(id).getElementsByTagName("span")[0].style.display = "none";
}

//Overlay Script

function openOverlay(view){
  var id = "#overlay_" + view;
  var win_width = $(window).width();
  var win_height = $(window).height();
  var overlay = $(id).innerWidth();
  var position = (win_width - overlay)/2;

  var index = 1;
  $(".overlay:visible").each(function(){
    zIndex = Number($(this).css("zIndex"))
    if(zIndex >= index){
      index = zIndex + 1;
    }
  });
  $(id).attr("style", "left:" + position + "px !important; z-index:" + index + ";");
  $(id).show();
  initializer();
}

function closeOverlay(view){
  view = view.replace("overlay_", "");
  var id = "#overlay_" + view;
  $(id).hide();
  $(id).html("");
}

// Optimize I'm sure there's a way to dry this up...
function fixNumber(input){
  var str = input.value;
  str = str.replace(/[A-Za-z$-]/g, '');
  input.value = str;
}

function fixNumberOnly(input){
  var str = input.value;
  str = str.replace(/[^0-9]/g, '');
  input.value = str;
}

function updatePrimary(input){
  $(input).closest('table').find('input.primary').each(function(){
    $(this).removeAttr('checked');
  });
  $(input).attr('checked', 'checked');
}

function updateAffiliations(type){
  var from = type;
  var to = document.getElementById('entity_IndCorp').value;
  var affiliations = "";

  if(from == "Individual" && to == "Individual"){
    affiliations = [
    "Brother",
    "Daughter",
    "Father",
    "Granddaughter",
    "Grandfather",
    "Grandmother",
    "Grandson",
    "Significant Other (Partner)",
    "Mother",
    "Son",
    "Spouse",
    "Employer",
    "Employee",
    "Partner",
    "Attorney",
    "Assistant",
    "Accountant",
    "Friend"
    ];
  }
  else if(from != "Individual" && to == "Individual"){
    affiliations = [
    "Employer",
    "Lender",
    "HOA",
    "Trust"
    ];
  }
  else if(from == "Individual" && to != "Individual"){
    affiliations = [
    "Manager",
    "Trustee",
    "President",
    "Employee",
    "HOA Handler",
    "Realtor",
    "Owner",
    "Director",
    "Broker",
    "Loan Officer",
    "Attorney",
    "Member",
    "Treasurer",
    "Vice President",
    "Branch Manager",
    "Developer",
    "Accountant"
    ];
  }
  else{
    affiliations = [
    "AKA",
    "DBA",
    "Lender",
    "Underwriter"
    ];
  }

  return affiliations;
}

$(function(){
  $.extend($.fn.disableTextSelect = function() {
      return this.each(function(){
          if($.browser.mozilla){ //Firefox
              $(this).css('MozUserSelect','none');
          } else if ($.browser.msie){ //IE
              $(this).bind('selectstart',function(){return false;});
          } else { //Opera, etc.
              $(this).mousedown(function(){return false;});
          }
      });
  });
  $('.noSelect').disableTextSelect(); // No text selection on elements with a class of 'noSelect'
});

function showSearchSpinner(container){
  $("#" + container).html("<p style='margin-top: 5px; padding-left: 5px;'><img src='assets/loading.gif' style='margin-right: 5px; width: 15px; position: relative; top: 4px;' />Searching...</p>");
}

function showZeroResults(container){
  $("#" + container).html("<p style='font-style: italic; color: #9B9B9B; padding-left: 5px; margin-top: 5px;'>Search returned 0 results.</p>");
}

// Checks the search type and replaces info as needed.
function check_type(){
  if($("#search_type").find(':selected').text() == 'Smart Text'){
    $('#smart_text_notice').show();
  } else {
    $('#smart_text_notice').hide();
  }

  if($("#search_type").find(':selected').text().indexOf('Date') != -1){
    $("#main_search_input").hide();
    $("#main_search_dates").show();
    $("#main_search_input").find("input").each(function(){$(this).val('');});
  }
  else if($("#search_type").find(':selected').text() == "Reservations"){
    $("#main_search_input").hide();
    $("#main_search_dates").hide();
    $("#main_search_input").find("input").each(function(){$(this).val('Reservation');});
    $("#main_search_dates").find("input").each(function(){$(this).val('');});
  }
  else{
    $("#main_search_dates").hide();
    $("#main_search_input").show();
    $("#main_search_dates").find("input").each(function(){$(this).val('');});
  }

  if($("#search_type").find(':selected').text().indexOf('File Number') != -1 || $("#search_type").find(':selected').text().indexOf('Bombed Date') != -1){
    $("#include_closed_control").hide();
    $("#include_closed").attr('disabled', true);
  }
  else if($("#include_closed_control").html() != undefined){
    $("#include_closed").attr('disabled', false);
    $("#include_closed_control").show();
  }
}

function initSearchDates(){
  $( "#from" ).datepicker({
    defaultDate: "+1w",
    changeMonth: true,
    onClose: function( selectedDate ) {
      $( "#to" ).datepicker( "option", "minDate", selectedDate );
    }
  });
  $( "#to" ).datepicker({
    defaultDate: "+1w",
    changeMonth: true,
    onClose: function( selectedDate ) {
      $( "#from" ).datepicker( "option", "maxDate", selectedDate );
    }
  });
}

function rowSelect(object, path, type){
  path = typeof path !== 'undefined' ? path : false;
  type = typeof type !== 'undefined' ? type : "post";

  if($(object).attr("class").indexOf("active_row") == -1){
    var container = $(object).closest('table');
    var current = $(container).find("tr.active_row");
    if($(current).html() != undefined){
      $(current).removeClass("active_row");
    }
    $(object).addClass("active_row");

    if(path){
      switch(type)
      {
      case "put":
        $.ajax({
          url: path,
          type: "PUT"
        });
        break;
      case "delete":
        $.ajax({
          url: path,
          type: "DELETE"
        });
        break;
      case "get":
        $.get(path);
        break;
      default:
        $.post(path);
      }
    }
  }
}

function toggle(object, path, type){
  path = typeof path !== 'undefined' ? path : false;
  type = typeof type !== 'undefined' ? type : "post";

  if($(object).attr("class").indexOf("active_row") == -1){
    var container = $(object).closest('table');
    var current = $(container).find("tr.active_row");
    if($(current).html() != undefined){
      $(current).removeClass("active_row");
    }
    $(object).addClass("active_row");

    if(path){
      switch(type)
      {
      case "put":
        $.ajax({
          url: path,
          type: "PUT"
        });
        break;
      case "delete":
        $.ajax({
          url: path,
          type: "DELETE"
        });
        break;
      case "get":
        $.get(path);
        break;
      default:
        $.post(path);
      }
    }
  }
  else{
    $(object).removeClass("active_row");
    $(object).next(".view").remove();
  }
}

function editInPlace(container, type, update_path){
  var editor = "";
  var value = $(container).text().replace(/"/g, '\"');

  $.each($("#edit_in_place"), function(){
    $(this).blur();
  });

  if(type == "text_field"){
    editor = "<input type=\"text\" onblur=\"$(this).closest('form').submit();\" id=\"edit_in_place\" onclick=\"event.stopPropagation();\" name=\"" + $(container).attr('field') + "\" style=\"width: 95%;\" value=\"" + value + "\" />";
  }

  $(container).html("<form action='" + update_path + "' method='put' data-remote='true'>" + editor.replace(/"/g, '\"') + "</form>")

  initializer();
  $("#edit_in_place").focus();
}

function create(path){
  $.post(path);
}

function update(path, sender){
  var type = $(sender).get(0).tagName;
  var value = "";

  if(type == "DIV"){
    if($(sender).html() == $(sender).data('before')){
      return;
    }
    value = encodeURIComponent($(sender).html()).replace(/%0A/g, "").replace(/%09/g, "").replace(/%3Cbr%3E$/, "");
  }
  else{
    value = encodeURIComponent($(sender).val());
  }

  operator = path.indexOf("?") == -1 ? "?" : "&"
  container = $(sender).attr('id') != undefined ? "&container=" + $(sender).attr('id') : ""
  $.ajax({
    url: path + operator + $(sender).attr('name') + "=" + value + container,
    type: "PUT"
  });
}

function destroy(path, remove){
  $.ajax({
    url: path,
    type: "DELETE",
    success: typeof remove !== 'undefined' && remove !== null ? $(remove).remove() : remove = "nothing"
  });
}

function validateSSN(object){
  if($(object).val().trim() != ""){
    var value = object.value;
    var validformat=/^\d{3}\-\d{2}\-\d{4}$/ ;
    var validnumbers =/^\d{9}$/ ;

    if(!validformat.test(value) && !validnumbers.test(value)){
      alert("Invalid SSN format. (Example: xxx-xx-xxxx)");
      object.value = "";
      return false;
    }
  }

  return true;
}

function validateDate(input){
  var value = input.value;
  var validformat=/^\d{2}\/\d{2}\/\d{4}$/ ;
  var split = value.split("/");

  if(value != "" && !validformat.test(value) ){
    if(value == ""){
      // do nothing
    }
    else{
      if(split.length == 1){
        split = value.split("-");
      }
    }

    if(split.length == 3){
      validformat=/^\d{2}\-\d{2}\-\d{4}$/ ;
      if(validformat.test(value)){
        value = split[0] + "/" + split[1] + "/" + split[2];
      }
      else{
        var day = "";
        var month = "";
        var year = "";

        split[0].length == 2 ? day = split[0] : day = "0" + split[0];
        split[1].length == 2 ? month = split[1] : month = "0" + split[1];
        if(split[2].length == 4){
          year = split[2];
        }
        else if(split[2].length == 2){
          date_year = String(new Date().getFullYear());
          century = date_year.slice(0,2);
          current = date_year.slice(2);

          Number(current) - Number(split[2]) > 0 || Number(split[2]) < Number(current) + 40 ? year = century + split[2] : year = Number(century) - 1 + split[2];
        }
        value = day + "/" + month + "/" + year;
      }
    }

    validformat=/^\d{2}\/\d{2}\/\d{4}$/ ;
    if(validformat.test(value)){
      // do nothing
    }
    else{
      alert("Invalid date format. Remember to use leading zeros and four digits for the year. (Example: 08/01/1987)");
      var e = jQuery.Event("keydown");
      e.keyCode = 27;
      $(input).trigger(e);
      return false;
    }
  }

  var monthfield=value.split("/")[0]
  var dayfield=value.split("/")[1]
  var yearfield=value.split("/")[2]
  var dayobj = new Date(yearfield, monthfield-1, dayfield)
  if (value != ""){
    if ((dayobj.getMonth()+1!=monthfield)||(dayobj.getDate()!=dayfield)||(dayobj.getFullYear()!=yearfield)){
      alert("Invalid Day, Month, or Year range detected. Please correct and submit again.")
      var e = jQuery.Event("keydown");
      e.keyCode = 27;
      $(input).trigger(e);
      return false;
    }
  }
  input.value = value;
  return true;
}

function validateDateTime(object){
  var value = $(object).val().replace(/\s\s/g, " ");

  if(value == ""){
    return false;
  }

  var valid_date=/^\d{2}\/\d{2}\/\d{4}$/ ;
  var valid_time1=/^\d{1}:\d{2}\s\w{2}$/ ;
  var valid_time2=/^\d{2}:\d{2}\s\w{2}$/ ;
  var split = value.split(" ")

  var date = split[0];
  var time = split[1];
  var ampm = split[2];

  if(!valid_date.test(date)){
    split = date.split("/");
    if(split.length == 1){
      split = value.split("-");
    }

    if(split.length == 3){
      validformat=/^\d{2}\-\d{2}\-\d{4}$/ ;
      if(validformat.test(value)){
        value = split[0] + "/" + split[1] + "/" + split[2];
      }
      else{
        var day = "";
        var month = "";
        var year = "";

        split[0].length == 2 ? day = split[0] : day = "0" + split[0];
        split[1].length == 2 ? month = split[1] : month = "0" + split[1];

        year_split = split[2].split(" ");
        if(year_split[0].length == 4){
          year = year_split[0];
        }
        else if(year_split[0].length == 2){
          date_year = String(new Date().getFullYear());
          century = date_year.slice(0,2);
          current = date_year.slice(2);

          Number(current) - Number(year_split[0]) > 0 || Number(year_split[0]) < Number(current) + 40 ? year = century + year_split[0] : year = Number(century) - 1 + year_split[0];
        }
        value = day + "/" + month + "/" + year;
      }
    }
  }
  else if(valid_time1.test(time + " " + ampm) || valid_time2.test(time + " " + ampm)){
    value = date;
  }
  else{
    return false;
  }

  var monthfield=value.split("/")[0]
  var dayfield=value.split("/")[1]
  var yearfield=value.split("/")[2].split(" ")[0]
  var dayobj = new Date(yearfield, monthfield-1, dayfield)
  if ((dayobj.getMonth()+1!=monthfield)||(dayobj.getDate()!=dayfield)||(dayobj.getFullYear()!=yearfield)){
    return false;
  }

  $(object).val(value + " " + time + " " + ampm);
  return true;
}

function verifySignature(){
  $('#signature_error').html("");
  $('#signature_error').hide();

  if($('#signature_description').val() == ""){
    $('#signature_error').html("<h4 style='text-decoration: underline'>The following errors occurred with your entry.</h4><h4>1) Description cannot be left blank.</h4>");
    $('#signature_error').show();
    return false;
  }
  else{
    return true;
  }
}

function numbersOnly(e)
{
  var keynum;
  var numcheck;

  if(window.event) // IE8 and earlier
  {
    keynum = e.keyCode;
  }
  else if(e.which) // IE9/Firefox/Chrome/Opera/Safari
  {
    keynum = e.which;
  }

  if ( keynum == 46 || keynum == 8 || keynum == 190 || keynum == 110 || keynum == 9 || keynum == 27 || keynum == 13 || keynum == 188 ||
    // Allow: Ctrl+A
    (keynum == 65 && e.ctrlKey) ||
    // Allow: home, end, left, right
    (keynum >= 35 && keynum <= 39) ||
    // Allow: - for negagtive numbers
    (keynum == 173 || keynum == 109)) {
    // let it happen, don't do anything

    return;
  }
  else {
    // Ensure that it is a number and stop the keypress
    if (e.shiftKey || (keynum < 48 || keynum > 57) && (keynum < 96 || keynum > 105 )) {
      e.preventDefault();
    }
  }
}

function toUSN(object) {
  if(object.value != ""){
    var number = object.value.toString().replace(/,/g, ''),
    dollars = number.split('.')[0],
    cents = (number.split('.')[1] || '') +'00';
    dollars = dollars.split('').reverse().join('')
        .replace(/(\d{3}(?!$))/g, '$1,')
        .split('').reverse().join('');
    object.value = dollars + '.' + cents.slice(0, 2);
  }
}

function toUSD(object) {
  if(object.value != ""){
    var number = object.value.toString().replace(/,/g, ''),
    dollars = number.split('.')[0],
    cents = (number.split('.')[1] || '') +'00';
    dollars = dollars.split('').reverse().join('')
        .replace(/(\d{3}(?!$))/g, '$1,')
        .split('').reverse().join('');
    object.value = "$" + dollars + '.' + cents.slice(0, 2);
  }
}

function strToUSN(value) {
  if(value != ""){
    var negative = false;
    var number = value.toString().replace(/,/g, ''),
    dollars = number.split('.')[0],
    cents = (number.split('.')[1] || '') +'00';

    if (dollars.indexOf("-") != -1) {
      negative = true;
      dollars = dollars.replace(/-/g, "");
    };

    dollars = dollars.split('').reverse().join('')
        .replace(/(\d{3}(?!$))/g, '$1,')
        .split('').reverse().join('');
    value = negative ? "-" + dollars + '.' + cents.slice(0, 2) : dollars + '.' + cents.slice(0, 2);
  }
  return value
}

function strToUSD(value) {
  if(value != ""){
    var negative = false;
    var number = value.toString().replace(/,/g, ''),
    dollars = number.split('.')[0],
    cents = (number.split('.')[1] || '') +'00';

    if (dollars.indexOf("-") != -1) {
      negative = true;
      dollars = dollars.replace(/-/g, "");
    };

    dollars = dollars.split('').reverse().join('')
        .replace(/(\d{3}(?!$))/g, '$1,')
        .split('').reverse().join('');
    value = negative ? "-$" + dollars + '.' + cents.slice(0, 2) : "$" + dollars + '.' + cents.slice(0, 2);
  }
  return value
}