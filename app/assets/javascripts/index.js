var requests = [];
var dragTimer;
var currentSize;
var search_results_down = false;

$(document).ready(function(){
  $(document).mousedown(function() {
    down = true;
  }).mouseup(function() {
    down = false;
  });
  // On-click of table rows in main search
  $('#index_results').on("click", "tr", function(event) {
    // Don't request row that is already active
    if ($(this).hasClass("active_row")){return null}

    var object = $(this);
    clearRows();
    object.toggleClass('active_row');
    for(var i = 0; i < requests.length; i++)
    requests[i].abort();
    var xhr = $.ajax({
      url: Routes.index_path({id: object.attr("id")})
    });
    requests.push(xhr);
  });

  // Find the first result and click it
  $("#search_results").find(".result_row").first().click();
  $("#search_results").resizable({
    grid: 23
  });

  $("#search_results").resizable( "option", "helper", "resizable-helper" );
  $(".ui-icon-gripsmall-diagonal-se").remove();
  $(".ui-resizable-e").remove();
  $(".ui-resizable-handle").attr("style","z-index: 1;");

  $(".ui-resizable-handle").mousedown(function() {
    $(".ui-resizable-handle").css("background-color","#ddd");
    currentSize = $("#search_results").height();
    search_results_down = true;
  });

  $("body").mouseup(function(){
    if(search_results_down){
      $(".ui-resizable-handle").css("background-color","#fff");
      if(currentSize != $("#search_results").height()){
        $.ajax({
          url: "/users_preferences/update?name=index_result_count&value=" + $("#search_results").height()/23,
          type: "PUT"
        })
      }
    }
  });

  initializer();
  if($("#search_box").val() != ""){
    $("#search_button").click();
  }
  $('body').attr("ondragover", "onDragOver(event);");
  $('body').attr("ondragleave", "onDragLeave(event);");
  $('body').attr("ondrop", "onDragDrop(event);");
  $("#search_box").focus();
  check_type();

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
});

function indexInit(id){
  var scrollTo
  var file = id;
  var container = $("#search_results");
  display_file_id = $("#display_file_id").html();

  formatFax();
  formatPhone();

  $("#datepicker").datetimepicker({
    minDate: 0,
    ampm: true,
    timeFormat: 'h:mm TT',
    stepMinute: 5,
    changeMonth: true,
    changeYear: true
  });

  if(file == ""){
    if($('tr.record:first').html() != undefined){
      $('tr.record:first').click();
      container.scrollTop(0);
    }
  } else {
    scrollTo = $("tr#index_row_" + file);
    $("tr#index_row_" + file).click();
    container.scrollTop(scrollTo.offset().top - container.offset().top + container.scrollTop());
  }
}

function onDragOver(e){
  var dt = e.dataTransfer;
  if(dt.types != null && (dt.types.indexOf ? dt.types.indexOf('Files') != -1 : dt.types.contains('application/x-moz-file'))) {
    e.preventDefault();
    $("div#filebin_overlay").addClass("dragenter");
    $("h1#filebin_overlay_text").show();
    $("h1#filebin_overlay_text").html("<center>Upload Attachment To<br />File #" + $("#tab_file_id").html() + "</center>");
    clearTimeout(dragTimer);
  }
}

function onDragLeave(){
  dragTimer = setTimeout(function(){
    $("div#filebin_overlay").removeClass("dragenter");
    $("h1#filebin_overlay_text").hide();
  }, 25);
}

function uploadFile(blobFile, fileName, filePart, totalChunks, identifier) {
  var file_id = $("#page_company_id").val() + $("td#file_id").html()
  var csrf_token = $('meta[name=csrf-token]').attr('content');
  var csrf_param = $('meta[name=csrf-param]').attr('content');
  var formData = new FormData();
  formData.append('file', blobFile);

  // now post a new XHR request
  var params;
  if (csrf_param !== undefined && csrf_token !== undefined) {
    params = csrf_param + "=" + encodeURIComponent(csrf_token);
  }
  params = params + "&display_file_id=" + file_id + "&filename=" + fileName + "&filepart=" + filePart + "&totalchunks=" + totalChunks + "&identifier=" + identifier

  $.ajaxq(identifier,{
    url: '/file_images/dnd_upload?' + params,
    type: "POST",
    xhr: function() {
      var myXhr = $.ajaxSettings.xhr();
      return myXhr;
    },
    data: formData,
    cache: false,
    contentType: false,
    processData: false
  });
}

function onDragDrop(e) {
  var file_id = $("#page_company_id").val() + $("td#file_id").html()
  var files = e.dataTransfer.files;

  if(files.length > 5){
    alert("Can only upload up to 5 files at a time.");
    $("div#filebin_overlay").removeClass("dragenter");
    $("h1#filebin_overlay_text").hide();
    e.preventDefault();
  } else {
    for(var i = 0; i < files.length; i++) {
      if(files[i].type == ""){
        alert("No file type detected, file must have an extension!");
        $("div#filebin_overlay").removeClass("dragenter");
        $("h1#filebin_overlay_text").hide();
        e.preventDefault();
      } else if($("span#display_file_id").html() == "undefined") {
        alert("File not finished loading yet");
      } else {
        $("div#filebin_overlay").removeClass("dragenter");
        $("h1#filebin_overlay_text").hide();
        e.preventDefault();
        this.className = '';

        // Add task to taskbar
        var identifier = "task-" + files[i].name + "-" + makeId()
        $.ajaxq(identifier,{
          url: "/application/add_task?title=" + files[i].name + "-0%25&identifier=" + identifier + "&type=file&id=" + file_id,
          type: "get"
        });

        // ASYNC File Upload
        var file             = files[i];
        var blobs            = [];
        var blob             = file;
        var originalFileName = blob.name;
        var filePart         = 0

        const BYTES_PER_CHUNK = 5242880; // 5MB chunk sizes.
        const SIZE = blob.size;

        var start = 0;
        var end = BYTES_PER_CHUNK;

        totalChunks = Math.ceil(SIZE / BYTES_PER_CHUNK);

        while( start < SIZE ) {
          chunk = blob.slice(start, end);
          uploadFile(chunk, originalFileName, filePart, totalChunks, identifier);

          filePart++;
          start = end;
          end = start + BYTES_PER_CHUNK;
        }
      }
    }
  }
}

// New Order Form
function validateNewOrder(form){
  var test;
  var errors = "";
  var properties = 0;
  var closers = 0;
  var searchers = 0;
  var fail = false;

  if($("input#index_SalesPrice").val() == "" && $("input#index_LoanAmount").val() == ""){
    errors += "&list[]=New order must have an amount of $0.00 or greater to open.";
  }

  if($("#order_info #side input").val() == ""){
    errors += "&list[]=You must select which side, or BOTH if applicable, that we are closing."
  }

  $('#new_file_properties').find('tr').each(function(){
    if($(this).attr('id') != undefined){
      test = "";
      $(this).find("input[type=text]").each(function(){
        (["State", "Remind", "City", "Zip"].indexOf($(this).data('field')) == -1) ? test += $(this).val() : test += "";
      });
      if(test != ""){
        properties += 1;
      }
    }
  });

  var name = "";
  var position = 0;
  $('#new_file_employees').find('tr').each(function(){
    if($(this).attr('id') != undefined){
      $(this).find("select").each(function(){
        $(this).data('field') == "EmployeeID" ? name = $(this).val() : name += "";
        $(this).data('field') == "Position" && ["3", "4", "5"].indexOf($(this).val()) != -1 ? closers += 1 : closers += 0;
        $(this).data('field') == "Position" && ["7"].indexOf($(this).val()) != -1 ? searchers += 1 : searchers += 0;
      });
      if(name == ""){
        fail = true;
      }
    }
  });

  if(closers == 0){
    errors += "&list[]=There must be at least one closer associated with this order to open.";
  }

  if(fail){
    errors += "&list[]=One or more employee names are missing.";
  }

  if(properties == 0){
    errors += "&list[]=There must be at least one property associated with this order to open. Property must include one of the following: Tax ID, Account Number, Address, or Legal Description.";
  }

  if($('#new_file_contacts').find('tr').length == 0){
    errors += "&list[]=There must be at least one contact associated with this order to open.";
  }

  if(typeof $("#new_order_confidential") !== undefined && $("#new_order_confidential").attr("checked") == "checked"){
    if($("select#index_Underwriter").val() == ""){
      errors += "&list[]=Confidential Files: You must select an underwriter.";
    }
    if(searchers == 0){
      errors += "&list[]=Confidential Files: There must be at least one searcher associated with this order to open.";
    }
  }

  if(errors != ""){
    addToQueue("validate_new_order", "/application/flash_notice?title=Errors on Form&notice=Please correct the following errors before proceeding:" + errors);
  }
  else{
    var pr_out = false;
    var confirmation_out = false;
    list = "";

    $('#new_file_properties').find('tr').each(function(){
      if($(this).attr('id') != undefined){
        test = "";
        $(this).find("input[type=text]").each(function(){
          (["State", "Remind"].indexOf($(this).data('field')) == -1) ? test += $(this).val() : test += "";
        });
        if(test == ""){
          $(this).remove();
        }
      }
    });

    $('#new_file_notes').find('tr').each(function(){
      if($(this).attr('id') != undefined){
        test = "";
        $(this).find("input[type=text]").each(function(){
          (["State", "Remind", "IsPrivate"].indexOf($(this).data('field')) == -1) ? test += $(this).val() : test += "";
        });
        if(test == ""){
          $(this).remove();
        }
      }
    });

    $('#new_file_contacts').find('tr').each(function(){
      if($(this).attr('id') != undefined){
        $(this).find("input[type=checkbox]").each(function(){
          if($(this).data('field') == 'PR' && $(this).attr('checked') == 'checked'){
            pr_out = true;
          }
          else if($(this).data('field') == 'Confirmation' && $(this).attr('checked') == 'checked'){
            confirmation_out = true;
          }
        });
      }
    });

    $('#new_order_button_container').find('input').attr('disabled', true);
    $('#new_order_button_container').find('input').blur();

    if($('#new_file_contacts').find('tr').length > 0 && (pr_out == false || confirmation_out == false) ){
      if(pr_out == false){
        list += "&list[]=No one is selected to receive a PR.";
      }
      if(confirmation_out == false){
        list += "&list[]=No one is selected to receive an Order Confirmation.";
      }
      addToQueue('confirm_new_order', 'application/flash_notice?&title=Warning&notice=The following warning(s) have been raised. Do you wish to continue?&confirm=Yes&click_action=' + encodeURIComponent('$(\'form#new_index\').submit();') + '&cancel_action=' + encodeURIComponent('$(\'#new_order_button_container input\').attr(\'disabled\', false);') + list );
      return false;
    }

    addToQueue('confirm_new_order', 'application/flash_notice?&title=Confirm New Order&notice=Are you ready to open this order?&confirm=Yes&click_action=' + encodeURIComponent('$(\'form#new_index\').submit();') + '&cancel_action=' + encodeURIComponent('$(\'#new_order_button_container input\').attr(\'disabled\', false);') );
    return true;
  }
  return false;
}

function validateCloser(sender){
  var row = $(sender).closest('tr');
  var position_select = $(row).find('select[data-field=Position]');
  var employee_id = $(row).find('select[data-field=EmployeeID]').val();

  if($(position_select).find(":selected").text().indexOf("Closer") != -1){
    var position = $(position_select).val();

    $(row).attr('id', 'new_employee_rowVALIDATING');
    addToQueue('update_employee_row', '/file_employees/update_employee_row?company=' + $("#page_company_id").val() + '&employee_id=' + employee_id + '&position=' + position );
  }
}

function initIndexFormPosition(object){
  var table = $(object).closest('table');
  var section = $(object).data('section');
  var count = 1;
  var field = "";
  var name = "";
  var plural = "";

  if(section == "property"){
    plural = "properties";
    check_for_duplicate_properties();
  }
  else{
    plural = section + "s";
  }

  $(table).find('tr').each(function(){
    // Check to make sure that we're not on header row
    if($(this).attr('id') != undefined){
      // Update blank rows
      if($(this).attr('id').indexOf('_BLANK') != -1){
        $(this).attr('id', $(this).attr('id').replace( /[0-9]/g, "" ) + String(count) );
      }

      // Update all inputs and selects so they are grouped correctly when it comes time to save
      $(this).find('select, input').each(function(){
        field = $(this).data('field');
        name = plural + "[" + section + String(count) + "[" + field + "]]" ;
        $(this).attr('name', name);
      });
    }
    count += 1;
  });
}

function refreshIndexFormPosition(object){
  var table = $(object).closest('table');
  var section = $(object).data('section');
  var count = 1;
  var field = "";
  var name = "";
  var id = "";
  var plural = "";
  $(object).remove();

  if(section == "property"){
    plural = "properties";
    check_for_duplicate_properties();
  }
  else{
    plural = section + "s";
  }

  $(table).find('tr').each(function(){
    // Check to make sure that we're not on header row
    if($(this).attr('id') != undefined){
      // Update blank rows
      if($(this).attr('id').indexOf('_BLANK') != -1){
        $(this).attr('id', $(this).attr('id').replace( /[0-9]/g, "" ) + String(count) );
      }

      // Update all inputs and selects so they are grouped correctly when it comes time to save
      $(this).find('select, input').each(function(){
        field = $(this).data('field');
        name = plural + "[" + section + String(count) + "[" + field + "]]" ;
        $(this).attr('name', name);
      });
    }
    count += 1;
  });
}

function updateIndexFormCurrent(view){
  var name = "";
  var position = "";
  var email = "";
  var phone = "";
  var id = "";
  var row = "";
  var click = "";
  var length = 15;
  var full_id = "";

  switch(view){
    case "employees":
      addToQueue('update_employee_options', '/index/update_employee_options?company=' + $('#page_company_id').val() + '&checked=' + $("#all_employees").attr('checked') );
      if($("#employees_on_new_order").html() != undefined){
        $("#employees_on_new_order").html('');
        if($("#new_file_employees").find('tr').length > 5){
          addWidth('current_employee', 95);
        }
        else{
          fixWidth('current_employee', 95);
        }
      }

      if($("#new_file_employees").find('tr').length > 0){
        $("#new_file_employees").find('tr').each(function(){
          $(this).find('select').each(function(){
            if($(this).data("field") == "EmployeeID"){
              name = $(this).find(":selected").text();
              id = $(this).val();
              $("#employee_button_" + id).attr('disabled', 'disabled').val('Added');
            }
            else{
              position = $(this).find(":selected").text();
            }
          });
          $(this).find('input[type=hidden]').each(function(){
            if($(this).data("field") == "email"){
              email = $(this).val();
            }
            else{
              phone = $(this).val();
            }
          });
          if($("#employees_on_new_order").html() != undefined && id != ""){
            name = evalLengthIndexForm(name);
            position = evalLengthIndexForm(position);
            email = evalLengthIndexForm(email);
            phone = evalLengthIndexForm(phone, true);

            row = "$('tr#new_employee_row" + id + "')";
            click = "refreshIndexFormPosition(" + row + "); $('#employee_button_" + id + "').prop('disabled', false).val('Add'); $(this).closest('tr').remove();";
            $("#employees_on_new_order").append("<tr><td style='padding-left: 5px; width: 95px;'><input type='button' value='Remove' onclick=\"" +  click + "\" /></td>" + name +  position + phone + email + "</tr>");
          }
        });
        initIndexFormPosition( $("#new_file_employees").find('tr:first') );
      }
      break;
    case "contacts":
      if($("#contacts_on_new_order").html() != undefined){
        $("#contacts_on_new_order").html('');
        if($("#new_file_contacts").find('tr').length > 5){
          addWidth('current_contact', 150);
        }
        else{
          fixWidth('current_contact', 150);
        }
      }

      if($("#new_file_contacts").find('tr').length > 0){
        var home_phone = "";
        var work_phone = "";
        var cell_phone = "";
        // var fax_num = "";
        var email = "";

        $("#new_file_contacts").find('tr').each(function(){
          $(this).find('td').each(function(){
            if($(this).data("field") != undefined){
              if($(this).data("field") == "ContactName"){
                if($(this).find('span').html() == undefined){
                  name = $.trim($(this).text());
                }
                else{
                  name = $.trim($(this).find('span').text());
                }
                id = $(this).find('input[type=hidden]').val();
                $("#contact_button_" + id).val('Added');
              }
              else if($(this).data("field") == "HomePhone"){
                home_phone = $.trim($(this).find('input').val());
              }
              else if($(this).data("field") == "WorkPhone"){
                work_phone = $.trim($(this).find('input').val());
              }
              else if($(this).data("field") == "CellPhone"){
                cell_phone = $.trim($(this).find('input').val());
              }
              else if($(this).data("field") == "FaxNum"){
                fax_num = $.trim($(this).find('input').val());
              }
              else if($(this).data("field") == "Email"){
                email = $.trim($(this).find('input').val());
              }
              // if($(this).data("field") == "ContactName"){
              //   if($(this).find('span').html() == undefined){
              //     name = $.trim($(this).text());
              //   }
              //   else{
              //     name = $.trim($(this).find('span').text());
              //   }
              //   id = $(this).find('input[type=hidden]').val();
              //   $("#contact_button_" + id).attr('disabled', 'disabled').val('Added');
              // }
              // else if($(this).data("field") == "HomePhone"){
              //   home_phone = $.trim($(this).text());
              // }
              // else if($(this).data("field") == "WorkPhone"){
              //   work_phone = $.trim($(this).text());
              // }
              // else if($(this).data("field") == "CellPhone"){
              //   cell_phone = $.trim($(this).text());
              // }
              // else if($(this).data("field") == "FaxNum"){
              //   fax_num = $.trim($(this).text());
              // }
              // else if($(this).data("field") == "Email"){
              //   if($(this).find('span').html() == undefined){
              //     email = $.trim($(this).text());
              //   }
              //   else{
              //     email = $.trim($(this).find('span').text());
              //   }
              // }
            }
          });

          $(this).find('select').each(function(){
            if($(this).data("field") == "Position"){
              position = $(this).find(":selected").text();
            }
          });
          if($("#contacts_on_new_order").html() != undefined && id != ""){
            row = "$('tr#new_contact_row" + id + "')";
            click = "refreshIndexFormPosition(" + row + "); $('#contact_button_" + id + "').val('Add'); updateIndexFormCurrent('contacts'); //$(this).closest('tr').remove();";

            // name = evalLengthIndexForm(name);
            if(name.length > length){
              name = "<td class='hint' style='padding-left: 5px; width: 95px;'><span><a href='rolodex?entity_id=" + id + "' target='_blank'>" + name + "</a></span><a href='rolodex?entity_id=" + id + "' target='_blank'>" + name.slice(0, length - 3) + "...</a></td>";
            }
            else{
              name = "<td style='padding-left: 5px; width: 95px;'><a href='rolodex?entity_id=" + id + "' target='_blank'>" + name + "</a></td>";
            }
            position = evalLengthIndexForm(position);
            home_phone = evalLengthIndexForm(home_phone);
            work_phone = evalLengthIndexForm(work_phone);
            cell_phone = evalLengthIndexForm(cell_phone);
            // fax_num = evalLengthIndexForm(fax_num);
            fax_num = "";
            email = evalLengthIndexForm(email);

            $("#contacts_on_new_order").append("<tr><td style='width: 60px; padding-left: 5px;'><input type='button' value='Remove' onclick=\"" +  click + "\" /></td>" + name + position + home_phone + work_phone + cell_phone +  fax_num +  email + "</tr>");
          }
        });
        initIndexFormPosition( $("#new_file_contacts").find('tr:first') );
      }
      break;
    case "properties":
      var tax_id;
      var account_id;
      var address;
      var legal;
      if($("#properties_on_new_order").html() != undefined){
        $("#properties_on_new_order").html('');
        if($("#new_file_properties").find('tr').length > 5){
          addWidth('current_properties', 95);
        }
        else{
          fixWidth('current_properties', 95);
        }
      }

      if($("#new_file_properties").find('tr').length > 0){
        $("#new_file_properties").find('tr').each(function(){
          if ($(this).attr('id') != undefined){
            full_id = $(this).attr('id')
            tax_id = "-";
            account_id = "-";
            address = "-";
            legal = "-";

            if($(this).attr('id') == "new_property_row_BLANK"){
              $(this).attr('id', "new_property_row_BLANK" + String($("#new_file_properties").find('tr').length) );
            }
            else{
              id = $(this).attr('id').replace("new_property_row", "");
            }

            $(this).find('select, input').each(function(){
              switch($(this).data("field")){
                case "TaxID":
                  tax_id = $.trim($(this).val());
                  break;
                case "AccountID":
                  account_id = $.trim($(this).val());
                  break;
                case "Address":
                  address = $.trim($(this).val());
                  break;
                case "LegalDescription":
                  legal = $.trim($(this).val());
                  break;
              }
            });

            tax_id = evalLengthIndexForm(tax_id);
            account_id = evalLengthIndexForm(account_id);
            address = evalLengthIndexForm(address);
            legal = evalLengthIndexForm(legal);

            if($("#properties_on_new_order").html() != undefined && full_id != ""){
              if($("#property_button_" + id).val() != undefined){
                click = "$('#property_button_" + id + "').prop('disabled', false).val('Add'); "
                $("#property_button_" + id).attr('disabled', 'disabled').val('Added');
              }

              row = "$('tr#" + full_id + "')";
              click += "refreshIndexFormPosition(" + row + "); $(this).closest('tr').remove();";
              $("#properties_on_new_order").append("<tr><td style='padding-left: 5px; width: 95px;'><input type='button' value='Remove' onclick=\"" +  click + "\" /></td>" + tax_id +  account_id + address + legal + "</tr>");
            }
          }
        });
        initIndexFormPosition( $("#new_file_properties").find('tr:first') );
      }
      break;
    case "notes":
      $("#new_file_notes").find('tr').each(function(){
        if ($(this).attr('id') != undefined && $(this).attr('id') == "new_note_row_BLANK"){
          $(this).attr('id', "new_note_row_BLANK" + String($("#new_file_notes").find('tr').length) );
        }
      });

      if($("#new_file_notes").find('tr').length > 0){
        initIndexFormPosition( $("#new_file_notes").find('tr:first') );
      }
      break;
  }
}

function evalLengthIndexForm(string, is_phone){
  if(is_phone == undefined){
    long_class_name = "class='hint'";
    short_class_name = "";
  }
  else{
    long_class_name = "class='hint phone'";
    short_class_name = "class='phone'";
  }
  var length = 15;
  if(string.length > length){
    string = "<td " + long_class_name + " style='padding-left: 5px; width: 95px;'><span>" + string + "</span>" + string.slice(0, length - 3) + "...</td>";
  }
  else{
    string = "<td " + short_class_name + " style='padding-left: 5px; width: 95px;'>" + string + "</td>";
  }
  return string
}

function check_for_duplicate_properties(){
  var taxid = '';
  var accountnum = '';
  $('#new_file_properties').find('input.taxid').each(function(){
    if($(this).val() != ""){
      taxid += '&taxid[]=' + $(this).val();
    }
  });
  $('#new_file_properties').find('input.account').each(function(){
    if($(this).val() != ""){
      accountnum += '&accountnum[]=' + $(this).val();
    }
  });
  addToQueue('unique_tax_id', "/index/unique_tax_id?company=" + $("#page_company_id").val() + taxid + accountnum);
}

function fill_property_row(object){
  var taxid = '';
  var accountnum = '';
  var field = '';
  var county_id = $(object).closest('tr').find('select').eq(0).val();

  $('#new_file_properties').find('input.taxid').each(function(){
    if($(this).val() != ''){
      taxid += '&taxid[]=' + $(this).val();
    }
  });
  $('#new_file_properties').find('input.account').each(function(){
    if($(this).val() != ''){
      accountnum += '&accountnum[]=' + $(this).val();
    }
  });

  if($(object).attr('class').indexOf("taxid") != -1){
    field = 'serialnum';
  }
  else{
    field = 'accountnum';
  }

  addToQueue('fill_property_row', 'index/fill_property_row?county_id=' + county_id + '&row=' + $(object).closest('tr').attr('id') + '&field=' + field + '&company=' + $('#page_company_id').val() + '&value=' + $(object).val() + taxid + accountnum);
}

function searchProperty(sender){
  var parent = $(sender).closest('tr');
  var tax_id = encodeURIComponent( $(parent).find('.taxid').eq(0).val()).replace(/\s/g, "+");
  var address = encodeURIComponent( $(parent).find('.address').eq(0).val()).replace(/\s/g, "+");
  var city = encodeURIComponent( $(parent).find('.city').eq(0).val()).replace(/\s/g, "+");
  var state = encodeURIComponent( $(parent).find('.state').eq(0).val()).replace(/\s/g, "+");
  var zip = encodeURIComponent( $(parent).find('.zip').eq(0).val()).replace(/\s/g, "+");

  params = [];
  tax_id != "" ? params.push("tax_id=" + tax_id) : "";
  address != "" ? params.push("address1=" + address) : "";
  city != "" ? params.push("city=" + city) : "";
  state != "" ? params.push("state=" + state) : "";
  zip != "" ? params.push("zip=" + zip) : "";

  $.post('application/usps?' + params.join("&") );
}
//

function dbl_click_search(cell){
  var field = $(cell).data("field");
  var type = "";

  if(field == "Name"){
    $("#search_box").val( $(cell).data("value") );
    type = $(cell).next().find(":selected").text();

    if(["Buyers Agent", "Listing Agent", "Realtor"].indexOf(type) != -1){
      $("#search_type").val("12").change();
    }
    else if(type == "Lender"){
      $("#search_type").val("10").change();
    }
    else{
      $("#search_type").val("38").change();
    }
  }
  else if(field == "TaxID"){
    $("#search_type").val("11").change();
    if($(cell).find('span').length > 0){
      $("#search_box").val( $(cell).find('span').text() );
    }
    else{
      $("#search_box").val( $(cell).text() );
    }
  }
  $("#search_button").click();
}

function submitSearch(){
  check_numeric();
  $('#search_results').show();
  $('#search_collapsed').hide();
  $('#search_expanded').show();
  $('#search_bar').find('input').each(function(){
    $(this).attr('readonly', true)
  });
  $('#search_button').hide();
  $('#include_closed_control').hide();
  $('#spinner').show();
  $('#searching_text').show();
  return true
}

function check_numeric(){
  if ($("#search_type").find(":selected").text() == "File Number" && isNaN($("#search_box").val())){
    $("#search_type").val("38").change();
  }
}

function postOverview() {
  $.post('index/overview')
}

function clearRows() {
  $('tr.active_row').removeClass('active_row').addClass('record');
};

function showTransactionFields(value){
  var loan = ["10", "3"];
  var cash = ["1"];

  if(cash.indexOf(value) != -1){
    $("#order_info tr#sales_price").show();

    $("#order_info tr#loan_amount").hide();
    $("#order_info tr#loan_number").hide();
    $("#order_info tr#loan_amount").find('input').each(function(){
      $(this).val('');
    });
    $("#order_info tr#loan_number").find('input').each(function(){
      $(this).val('');
    });

    $("#order_info #side select").attr("disabled", true);
    $("#order_info #side select").val("Owner").change();
    $("tr#split_with").hide();
    $("tr#split_with select").val('').change();
  }
  else if(loan.indexOf(value) != -1){
    $("#order_info tr#loan_amount").show();
    $("#order_info tr#loan_number").show();

    $("#order_info tr#sales_price").hide();
    $("#order_info tr#sales_price").find('input').each(function(){
      $(this).val('');
    });

    $("#order_info #side select").attr("disabled", true);
    $("#order_info #side select").val("Lender").change();
    $("tr#split_with").hide();
    $("tr#split_with select").val('').change();
  }
  else{
    $("#order_info #side select").attr("disabled", false);
    $("#order_info").find('tr').show();
    $("tr#split_with").show();
  }
}

function showSplitField(value){
  var no_split = ["10", "3", "1"];
  var type = $("#index_TransactionType").val();

  if(no_split.indexOf(value) != -1 || value == "Both" || value == ""){
    $("tr#split_with").hide();
    $("tr#split_with select").val('').change();
  }
  else{
    $("tr#split_with").show();
  }
}

$(document).ready(function() {
  $("input.number").keydown(function(event) {
    // Allow: backspace, delete, tab, escape, and enter
    if ( event.keyCode == 46 || event.keyCode == 8 || event.keyCode == 190 || event.keyCode == 9 || event.keyCode == 27 || event.keyCode == 13 ||
        // Allow: Ctrl+A
        (event.keyCode == 65 && event.ctrlKey === true) ||
          // Allow: home, end, left, right
          (event.keyCode >= 35 && event.keyCode <= 39)) {
      // let it happen, don't do anything
      return;
    }
    else {
      // Ensure that it is a number and stop the keypress
      if (event.shiftKey || (event.keyCode < 48 || event.keyCode > 57) && (event.keyCode < 96 || event.keyCode > 105 )) {
        event.preventDefault();
      }
    }
  });
});

// Update the value of a select to the end of the add link for post request in file_employees and file_entities position column
function update_position(row_id, value) {
  // Replaced to support buttons rather than hyperlinks
  $("#add_link_" + row_id).find('form').attr('action', $("#add_link_" + row_id).find('form').attr('action').replace(/&position=.{0,}/,''));
  $("#add_link_" + row_id).find('form').attr('action', $("#add_link_" + row_id).find("form").attr("action") + "&position=" + value);
}

// Optimize not DRY
function updateContactPosition(id){
  var table=document.getElementById("new_file_contacts");
  var all_rows = table.getElementsByTagName("tr");
  var c = -1;

  for( i=0; i < all_rows.length; i++){
    c++;
  }

  var cell = document.getElementById(id).getElementsByTagName("td")
  cell[0].getElementsByTagName("input")[0].name = "contacts[contact" + c + "[EntityID]]";
  cell[1].getElementsByTagName("select")[0].name = "contacts[contact" + c + "[Position]]";
  cell[2].getElementsByTagName("input")[0].name = "contacts[contact" + c + "[PR]]";

  document.getElementById("search_contact" + id.replace("new_contact_row", "")).getElementsByClassName("actions")[0].innerHTML = '<a onclick="removeContactFromNewOrder(' + "'" + 'new_contact_row' + id.replace("new_contact_row", "") + "'" + ')" class="trigger">Remove</a>';
}

function removeContactFromNewOrder(id){
  var row = document.getElementById(id).rowIndex;
  var table=document.getElementById("new_file_contacts");

  table.deleteRow(row);

  if(typeof document.getElementById("search_contact" + id.replace("new_contact_row", "")) != 'undefined'){
    document.getElementById("search_contact" + id.replace("new_contact_row", "")).getElementsByClassName("actions")[0].innerHTML = '<a class="trigger" href="index/add_contact_to_new_file/?entity_id=' + id.replace("new_contact_row", "") + '" data-remote="true">Add</a>';
  }
}

function updateEmployeePosition(id){
  var table=document.getElementById("new_file_employees");
  var all_rows = table.getElementsByTagName("tr");
  var c = -1;

  for( i=0; i < all_rows.length; i++){
    c++;
  }

  var cell = document.getElementById(id).getElementsByTagName("td")
  cell[0].getElementsByTagName("select")[0].name = "employees[employee" + c + "[EmployeeID]]";
  cell[1].getElementsByTagName("select")[0].name = "employees[employee" + c + "[Position]]";

  document.getElementById("search_employee" + id.replace("new_employee_row", "")).getElementsByClassName("actions")[0].innerHTML = '<a onclick="removeEmployeeFromNewOrder(' + "'" + 'new_contact_row' + id.replace("new_employee_row", "") + "'" + ')" class="trigger">Remove</a>';
}

function removeEmployeeFromNewOrder(id){
  var row = document.getElementById(id).rowIndex;
  var table=document.getElementById("new_file_employees");

  table.deleteRow(row);

  if(typeof document.getElementById("search_employee" + id.replace("new_employee_row", "")) != 'undefined'){
    document.getElementById("search_employee" + id.replace("new_employee_row", "")).getElementsByClassName("actions")[0].innerHTML = '<a class="trigger" href="index/add_employee_to_new_file/?employee_id=' + id.replace("new_employee_row", "") + '" data-remote="true">Add</a>';
  }
}

function updateNotePosition(id){
  var table=document.getElementById("new_file_notes");
  var all_rows = table.getElementsByTagName("tr");
  var c = -1;

  for( i=0; i < all_rows.length; i++){
    c++;
  }

  var cell = document.getElementById(id).getElementsByTagName("td")
  cell[0].getElementsByTagName("input")[0].name = "notes[note" + c + "[Note]]";
  cell[1].getElementsByTagName("select")[0].name = "notes[note" + c + "[From]]";
  cell[2].getElementsByTagName("select")[0].name = "notes[note" + c + "[To]]";
  cell[3].getElementsByTagName("input")[0].name = "notes[note" + c + "[Remind]]";

  document.getElementById(id).id += c;
  document.getElementById("datepicker").id += c;

  $( "#datepicker" + c ).datetimepicker({
    minDate: 0,
    ampm: true,
    timeFormat: 'h:mm TT',
    stepMinute: 5,
    changeMonth: true,
    changeYear: true
  });
}

function updatePropertyPosition(id){
  var table=document.getElementById("new_file_properties");
  var all_rows = table.getElementsByTagName("tr");
  var c = -1;

  for( i=0; i < all_rows.length; i++){
    c++;
  }

  var cell = document.getElementById(id).getElementsByTagName("td");
  cell[0].getElementsByTagName("input")[0].name = "properties[property" + c + "[TaxID]]";
  cell[1].getElementsByTagName("input")[0].name = "properties[property" + c + "[AccountID]]";
  cell[2].getElementsByTagName("input")[0].name = "properties[property" + c + "[Address]]";
  cell[3].getElementsByTagName("input")[0].name = "properties[property" + c + "[City]]";
  cell[4].getElementsByTagName("input")[0].name = "properties[property" + c + "[State]]";
  cell[5].getElementsByTagName("input")[0].name = "properties[property" + c + "[Zip]]";
  cell[6].getElementsByTagName("select")[0].name = "properties[property" + c + "[County]]";
  cell[7].getElementsByTagName("input")[0].name = "properties[property" + c + "[LegalDescription]]";

  if(id == "BLANK"){
    document.getElementById(id).id = "new_property_rowROW" + c;
  }
  else{
    document.getElementById("search_property" + id.replace("new_property_row", "")).getElementsByClassName("actions")[0].innerHTML = 'Added';
  }
}

function updateIndexInfo(object, id, type){
  var currency = ["SalesPrice", "LoanAmount", "SecondLoan"];
  var value = "";
  var parent = object.parentNode.parentNode

  if(currency.indexOf(type) != -1){
    value = formatCurrency(object.value);
  }
  else if(type.indexOf("TransactionDescription1") != -1 || type.indexOf("Underwriter") != -1){
    value = object.options[object.selectedIndex].text;
    if(value == ""){
      value = "Add"
    }
  }
  else if(type.indexOf("COEDate") != -1){
    if(validateDate(object)){
      value = object.value;
    }
    else{
      value = ""
      return false;
    }
  }
  else{
    value = object.value;
  }

  $('#' + id + type).click();
  parent.innerHTML = "<a style='color: #0054A0' data-remote='true' href='/index/" + id+ "/edit_file_info?type=" + type + "'>" + value + "</a>";
}

function expandCollapse(object){
  var container = document.getElementById(object.id.replace("container", "contents"));

  if(container.style.display.indexOf("none") == -1){
    container.style.display = "none";
    object.getElementsByTagName("img")[0].src = "/assets/plusgrey.png";
    object.getElementsByTagName("img")[0].className = "expand";
  }
  else{
    container.style.display = "block";
    object.getElementsByTagName("img")[0].src = "/assets/minusgrey.png";
    object.getElementsByTagName("img")[0].className = "collapse";
  }
}

// File Attachments //
function send_file(object){
  var list = getSelected(object);
  if(list != ''){
    addToQueue('send_images', 'file_images/send_images?do=overlay&file_id=<%= @file.FileID %>&type=file_images' + list);
  }else{
    addToQueue('send_error', 'application/flash_notice?notice=You need to select at an image to continue.');
  }
}

function view_log(object){
  addToQueue('view_log', 'file_images/view_log?file_id=<%= @file.FileID %>');
}

// Docs Javascript
$(document).ready().bind('keydown', function(e){
  if (e.which == '192')
  {
    $("div#doc_quickadd").toggle();
    $("input#quickadd_field").val("");
    $("input#quickadd_field").focus();
    return false;
  }
});

function updateCheckedBox(object){
  checked = object.checked;

  $("." + $(object).attr("class")).each(function(){
    if(this.checked == true){
      this.checked = false;
      this.value = this.getAttribute("data-box");
    }
  });

  $("input[name=" + $(object).attr("name") + "]").each(function(){
    this.checked = checked;

    if(this.checked == true){
      this.value = "0";
    }
    else{
      this.value = this.getAttribute("data-box");
    }
  });
}

function checkSplitParent(entity_id){
  var checked = $("#split_notary_" + entity_id).attr("checked");
  var children_checked = true;
  var children_exist = false;

  $("#doc_entity_" + entity_id + "_contents input[type=checkbox]").each(function(){
    if(this.checked == false){
      children_exist = true;
      children_checked = false;
    }
  });

  if(children_checked == true && checked == "checked" && children_exist == true){
    $.ajax({
      url: '/docs/toggle_split_notary?id=' + entity_id + '&type=entity',
      type: "PUT"
    });
    $("#split_notary_" + entity_id).removeAttr("checked");
    $("#split_notary_" + entity_id).attr("disabled", "disabled");
  }
  else if(children_checked == true){
    $("#split_notary_" + entity_id).attr("disabled", "disabled");
  }
  else{
   // $("#split_notary_" + entity_id).removeAttr("disabled");
  }
}

function selectDocRow(object, id){
  var parent = object.parentNode;
  var active = "";

  // document.getElementById("errors").style.display = "none";

  while(parent.tagName.indexOf( "TABLE" ) == -1) {
    parent = parent.parentNode;
  }

  if(parent.parentNode.id.indexOf("all_docs") != -1){
    if(document.getElementById("edit_doc") != undefined){
      document.getElementById("edit_doc").href = "docs/" + id + "/show_editor";
    }
  }

  if(parent.parentNode.id == "docs"){
    document.getElementById("copy_doc").href = "doc_templates/new?copy=" + id;
  }

  if(parent.getElementsByClassName("active_row").length > 0){
    active = parent.getElementsByClassName("active_row")[0];
    $(active).removeClass("active_row");
  }

  $(object).addClass("active_row");
  // object.getElementsByTagName("a")[0].click();
}

function removeClickFunction(object){
  var button = object.parentNode.getElementsByTagName("tr")[0];
  button.onclick = "";
  button.value = "Added";
  button.disabled = "disabled";
}

function collectDocs(object){
  var send = false;
  $("#all_docs input[type=checkbox]").each(function(){
    if(this.checked){
      object.href += "&docs[]=" + this.id.replace("doc", "");
      send = true;
    }
  });

  if(!send){
    $.post('application/flash_notice?notice=You do not have any documents selected.');
    return false;
  }
  else{
    return true;
  }
}

function destroySelected(object, list, file){
  var first = true;
  var destroy = false;
  var post = "docs/destroy?file_id=" + file;
  var doc_names = "";

  $("#" + list + " input[type=checkbox]").each(function(){
    if(this.checked){
      post += "%26docs[]=" + this.id.replace("doc", "");
      doc_names += "&list[]="+ encodeURIComponent( $(this).closest('tr').find('.name').eq(0).text() );
      destroy = true;
      //$(this).closest("tr.trigger").remove();
      //$("div#all_docs").find("tr").first().click();
    }
  });

  if(destroy){
        var message = "Are you sure you want to remove the selected docs?";
        var confirm = "Yes";
        $.post('application/flash_notice?request_type=delete&notice=' + message + '&post=' + post + '&confirm=' + confirm +  doc_names);
    return false;
  }
  else{
        $.post('application/flash_notice?notice=You need to select at least one document to remove.');
    return false;
  }
}

function saveSelected(object, list, file){
  var save = false;
  var hud = false;
  var count = 0;

  href = "docs/save?file_id=" + file;
  $("#" + list + " input[type=checkbox]").each(function(){
    if(this.checked){
      count += 1;
      if($(this).data("doc") == "HUD" || $(this).data("doc") == "SS"){
        hud = true;
      }
      href += "&docs[]=" + this.id.replace("doc", "");
      save = true;
    }
  });

  if(save){
    $("#doc_list_tools").hide();
    $("#doc_list_spinner").show();

    if(hud && count == 1){
      $.get("overlays/choose_side?file_id=" + file + "&href=" + href + "&only_hud=true");
      return false;
    }
    else if(hud){
      $.get("overlays/choose_side?file_id=" + file + "&href=" + href);
      return false;
    }
    else{
      $.get(href);
      return true;
    }
  }
  else{
    $.post("application/flash_notice?notice=You need to select at least one document to save.");
    return false;
  }
}

function printSelected(object, list, file){
  var print = false;
  var hud = false;
  //object.href = "docs/print?file_id=" + file;
  href = "docs/print?file_id=" + file;

  $("#" + list + " input[type=checkbox]").each(function(){
    if(this.checked){
      if($(this).data("doc") == "HUD" || $(this).data("doc") == "SS"){
        hud = true;
      }
      href += "&docs[]=" + this.id.replace("doc", "");
      print = true;
    }
  });

  if(print){
    $("#doc_list_tools").hide();
    $("#doc_list_spinner").show();

    if(hud){
      $.get('overlays/choose_side?file_id=' + file + '&href=' + href);
      return false;
    }
    else{
      $.get(href);
      return true;
    }
  }
  else{
    $.post('application/flash_notice?notice=You need to select at least one document to print.');
    return false;
  }
}

function print_doc_done(){
  $("div#doc_list_spinner").hide();
  $("div#doc_list_tools").show();
}

function selectDoc(object, select_all){
  var all = document.getElementById(select_all);

  if(all.checked){
    all.checked = false;
  }
}

$("input[type=checkbox]").click(function(event){
  event.stopPropagation();
});

function addDoc(object){
  button = object.parentNode.getElementsByTagName("input")[0];
  button.onclick = null;
  button.value = "Added";
  button.disabled = true;
}

function removeDoc(object){
  var r = confirm("Remove this doc?");
  return r;
  // if(r){
  //   // button = object.parentNode.getElementsByTagName("input")[0];
  //   // button.onclick = null;
  //   // button.value = "Removed";
  //   // button.disabled = true;
  //   return true;
  // }
  // else{
  //   return false;
  // }
}

function countMissingFields(){
  var count = 0;
  var containers = []; //["grantor_contents", "grantee_contents", "property_contents", "special_contents", "doc_specific_contents", "lender_contents"];

  $('div#doc_input_fields').find(".contents").each(function(){
    containers.push($(this).attr('id'));
  });

  for( i=0; i < containers.length; i++){
    if(containers[i] != undefined){
      count = 0;

      $("#" + containers[i] + " input").each(function(){
        if($(this).attr('id') != undefined && $(this).attr('id').indexOf("signature") == -1 && $(this).attr('id').indexOf("address_2") == -1){
          if($(this).val() != ""){
            $(this).removeClass("error");
            $(this).closest('tr').find('td').eq(0).removeClass("error");
          }
          else{
            $(this).addClass("error");
            $(this).closest('tr').find('td').eq(0).addClass("error");
            count += 1;
          }
        }
      });

      $("#" + containers[i] + " textarea").each(function(){
        if($(this).attr('id') != undefined && $(this).attr('id').indexOf("signature") == -1 && $(this).attr('id').indexOf("address_2") == -1){
          if($(this).val() != ""){
            $(this).removeClass("error");
            $(this).closest('tr').find('td').eq(0).removeClass("error");
          }
          else{
            $(this).addClass("error");
            $(this).closest('tr').find('td').eq(0).addClass("error");
            count += 1;
          }
        }
      });

      if(count > 0){
        if(count == 1){
          document.getElementById(containers[i].replace("contents", "missing")).innerHTML = count + " item";
        }
        else{
          document.getElementById(containers[i].replace("contents", "missing")).innerHTML = count + " items";
        }
      }
      else{
        document.getElementById(containers[i].replace("contents", "missing")).innerHTML = "";
      }
    }
  }
}

function updateCustomField(object, id, doc, file){
  var submit = document.getElementById("submit" + id);
  var new_id = object.id.replace("global", "custom");
  var functions = ["w9_ssn", "w9_tax_id"];
  var value = "";
  submit.click();

  var parent = object.parentNode;

  while(parent.tagName.indexOf( "SPAN" ) == -1) {
    parent = parent.parentNode;
  }

  if(new_id.indexOf(functions[0]) == -1 && new_id.indexOf(functions[1]) == -1){
    if(object.value == ""){
      html = "<a href='docs/edit_custom_field?file_id=" + file + "&doc_id=" + doc + "&field=" + new_id + "' data-remote='true' class='custom' onclick=\"if($('span.document_focus').html() != undefined){var e = jQuery.Event('keydown'); e.keyCode = 27; $('span.document_focus').children('form:first').children('textarea:first').trigger(e); $('span.document_focus').attr('class', '');} this.parentNode.className = 'document_focus'; \">{{" + new_id.replace("custom_", "").toUpperCase() + "}}</a>";
    }
    else{
      if( new_id.indexOf('full_property_address') != -1 && $("#doc_content .doc").data('doc') == '1099' && object.value.length > 39) {
        value = object.value.slice(0, 39);
        addToQueue('exceeded_character_notice', 'application/flash_notice?notice=Address exceeds character limit on 1099. Truncating to 39 characters.&confirm=Okay');
      }
      else{
        value = object.value;
      }
      html = "<a href='docs/edit_custom_field?file_id=" + file + "&doc_id=" + doc + "&field=" + new_id + "' data-remote='true' class='custom' onclick=\"if($('span.document_focus').html() != undefined){var e = jQuery.Event('keydown'); e.keyCode = 27; $('span.document_focus').children('form:first').children('textarea:first').trigger(e); $('span.document_focus').attr('class', '');} this.parentNode.className = 'document_focus'; \">" + value.replace(/\n/g, "<br>") +"</a>";
    }
  }
  else if(new_id.indexOf(functions[0]) != -1 || new_id.indexOf(functions[1]) != -1){
    $("tr#doc_" + doc).children("td:first").children("a:first").click();
    return false;
  }

  $(document.getElementsByName($(parent).attr("name"))).each(function(){
    $(this).html(html);
    $(this).attr("name", new_id);
    $(this).attr("id", new_id);
  });

  if($("span.document_focus").html() != undefined){
    $("span.document_focus").attr("class", "");
  }

  return true;
}

function revertToGlobal(object, file, doc){
  var id = $(object).attr("id");
  id = id.replace("global_", "");
  id = id.replace("custom_", "");
  id = id.replace("_button", "");
  var parent = $(object).parents("form:first").parents("span:first");
  var value = $("#" + id).val();
  var inner = value;
  var functions = ["w9_ssn", "w9_tax_id"];
  var empty = false;

  if(id.indexOf(functions[0]) != -1 || id.indexOf(functions[1]) != -1){
    $("tr#doc_" + doc).children("td:first").children("a:first").click();
    return false;
  }

  if(inner == ""){
    inner = $(object).attr("id");
    inner = inner.replace("global_", "");
    inner = inner.replace("custom_", "");
    inner = inner.replace("_button", "");
    inner = "{{" + inner.toUpperCase() + "}}";
    empty = true;
  }

  if(id.indexOf('full_property_address') != -1 && !empty && $("#doc_content .doc").data('doc') == '1099'  && inner.length > 39){
    inner = inner.slice(0, 39);
    addToQueue('exceeded_character_notice', 'application/flash_notice?notice=Address exceeds character limit on 1099. Truncating to 39 characters.&confirm=Okay');
  }

  var html = "<a href='docs/edit_custom_field?file_id=" + file + "&doc_id=" + doc + "&field=global_" + id + "' data-remote='true' class='complete' onclick=\"if($('span.document_focus').html() != undefined){var e = jQuery.Event('keydown'); e.keyCode = 27; $('span.document_focus').children('form:first').children('textarea:first').trigger(e); $('span.document_focus').attr('class', '');} this.parentNode.className = 'document_focus'; \">" + inner.replace(/\n/g, "<br>") +"</a>";

  $(document.getElementsByName($(parent).attr("name"))).each(function(){
    $(this).html(html);
    $(this).attr("name", "global_" + id);
    $(this).attr("id", "global_" + id);
  });

  if($("span.document_focus").html() != undefined){
    $("span.document_focus").attr("class", "");
  }

  return true;
}

function updateDocField(object){
  var id = "global_" + object.id;
  var value = object.value;
  var temp = "";
  var inner = value;
  var empty = false;

  if(inner == ""){
    inner = $(object).attr("id");
    inner = inner.replace("global_", "");
    inner = inner.replace("custom_", "");
    inner = inner.replace("_button", "");
    inner = "{{" + inner.toUpperCase() + "}}";
    empty = true;
  }

  if(id.indexOf('full_property_address') != -1 && !empty && $("#doc_content .doc").data('doc') == '1099'  && inner.length > 39){
    inner = inner.slice(0, 39);
    addToQueue('exceeded_character_notice', 'application/flash_notice?notice=Address exceeds character limit on 1099. Truncating to 39 characters.&confirm=Okay');
  }

  if(document.getElementById(id) != undefined){
    $("span#" + id).children("a").html(inner.replace(/\n/g, "<br />"));
  }

  countMissingFields();
}

function searchDocAddress(side){
  var address = encodeURIComponent( $("#" + side + "_address_1").val()).replace(/\s/g, "+");
  var address2 = encodeURIComponent( $("#" + side + "_address_2").eq(0).val()).replace(/\s/g, "+");
  var city = encodeURIComponent( $("#" + side + "_city").eq(0).val()).replace(/\s/g, "+");
  var state = encodeURIComponent( $("#" + side + "_state").eq(0).val()).replace(/\s/g, "+");
  var zip = encodeURIComponent( $("#" + side + "_zip").eq(0).val()).replace(/\s/g, "+");

  params = [];
  address != "" ? params.push("address1=" + address) : "";
  address2 != "" ? params.push("address2=" + address2) : "";
  city != "" ? params.push("city=" + city) : "";
  state != "" ? params.push("state=" + state) : "";
  zip != "" ? params.push("zip=" + zip) : "";

  $.get('application/usps?' + params.join("&") );
}

function updatePropertyAddressChars(sender){
  var string = $(sender).val();
  var length = string.length;

  if( length > 39){
    $('#full_address_chars').attr('class', 'error');
  }
  else{
    $('#full_address_chars').attr('class', '');
  }

  $('#full_address_chars').html(length + ' of 39 max characters.');
}

$("textarea#full_property_address").blur(function(event){
  var length = $("textarea#full_property_address").val().length;
  if( length > 39){
    $('#full_address_chars').attr('class', 'error');
  }
  else{
    $('#full_address_chars').attr('class', '');
  }

  $('#full_address_chars').html(length + ' of 39 max characters.');
});

function verifyNewEntity(){
  var message = "";

  if($("#individual_options").attr("style") == "display: block;"){
    if($("#individual_options #required").val() == ""){
      message = "First name cannot be left blank.";
    }
  }else{
    if($("#other_options #required").val() == ""){
      message = "Name cannot be left blank.";
    }
  }

  if(message == ""){
    return true;
  }else{
    $.post("application/flash_notice?notice=" + message);
    return false;
  }
}

function verifySendDocs(object){
  var count = 0;
  var recipients = false;
  var documents = false;
  var subject = false;
  var message = false;
  var error = document.getElementById("send_docs_form_errors");
  var send = true;

  error.innerHTML = "";

  $("#all_recipients input[type=checkbox]").each(function(){
    if(this.checked === true){
      recipients = true;
    }
  });

  $("#all_docs_to_send input[type=checkbox]").each(function(){
    if(this.checked === true){
      documents = true;
    }
  });

  if(document.getElementById("doc_subject").value !== ""){
    subject = true;
  }

  if(document.getElementById("doc_message").value !== ""){
    message = true;
  }

  if(recipients === false){
    count += 1;
    error.innerHTML = error.innerHTML + count + ") At least one recipient must be selected.<br />";
    send = false;
  }

  if(documents === false){
    count += 1;
    error.innerHTML = error.innerHTML + count + ") At least one document must be selected.<br />";
    send = false;
  }

  if(subject === false){
    count += 1;
    error.innerHTML = error.innerHTML + count + ") Subject line cannot be left blank.<br />";
    send = false;
  }

  if(message === false){
    count += 1;
    error.innerHTML = error.innerHTML + count + ") Message cannot be left blank.<br />";
    send = false;
  }

  if(send === true){
    closeOverlay('send');
    return true;
  }
  else{
    error.style.display = "";
    return false;
  }
}

function updateName(object){
  var signature = object.id.replace("name", "signature");
  var type = object.id.split("_")[0];
  var test = "";
  var parent_id = $(object).parents("tr:first").attr("id");
  var vesting = "";
  var vesting_value = "";

  $("#add_" + type + "_entities").show();

  if($("#" + signature).val() == "" ){
    test = $("#" + signature).attr("onchange");
    if(test.indexOf("create") != -1){
      $("#" + signature).val(object.value).change();
    }else{
      $("#" + signature).attr("onchange", $("#" + signature).attr("onchange").replace("create", "update"));
      $("#" + signature).val(object.value).change();
    }
  }

  if(parent_id == undefined){
    parent_id = $(object).parents("tbody:first").attr("id");
  }

  if(parent_id.indexOf("manage_") != -1){
    type = "manage_" + type;
  }

  var vesting = type + "_names";
  var vesting_value = $("#" + vesting).val();
  if(vesting_value != ""){
    vesting_value += " and ";
  }

  vesting_value += object.value;
  $("#" + vesting).val(vesting_value).change();

  img = $(object).parents("tbody:first").attr("id");
  $("#add_entity_to_" + img).show();
}

function removeEntityRow(object){
  var table = $(object).parents("table");
  var tbody = $(object).parents("tbody");

  $(table).find(tbody).remove();
}

function removeSignatureRow(object){
  var tbody = $(object).parents("tbody");
  var tr = $(object).parents("tr");
  var row = $(object).parents("tr:first");
  row.parents("tbody:first").children("tr:first").children("td:first").children("a:last").show();

  $(tbody).find(tr).remove();
}

function updatePosition(object, type, direction){
  if(type == 'signature'){
    var tbody = $(object).parents("tbody:first");
    var row = $(object).parents("tr:first");

    if(direction == "up" && tbody.children().index(row) > 1){
      row.insertBefore(row.prev());
    }
    else if(direction == "down" && tbody.children().index(row) < tbody.children().length - 1){
      row.insertAfter(row.next());
    }
    else{
    }
  }
  else if(type == 'entity'){
    var table = $(object).parents("table:first");
    var tbody = $(object).parents("tbody:first");

    if(direction == "up" && table.children().index(tbody) > 0){
      tbody.insertBefore(tbody.prev());
    }
    else if(direction == "down" && table.children().index(tbody) < table.children().length - 1){
      tbody.insertAfter(tbody.next());
    }
    else{
    }
  }
}

function toggleGlobal(object, type, doc_id){
  var row = $(object).parents("tr:first");
  var label = row.children("td:first");
  var element = "";
  var temp = "";
  var toggle = "";

  label_class = label.attr("class");
  if(label_class.indexOf("global") != -1){
    toggle = label.attr("class");
    toggle = toggle.replace("global", "custom");
    $(label).attr("class", toggle);
  }
  else{
    toggle = label.attr("class");
    toggle = toggle.replace("custom", "global");
    $(label).attr("class", toggle);
  }

  if(type == 'textarea'){
    element = row.children("td:last").children("textarea");
    if(label_class.indexOf("global") != -1){
      temp = element.attr("onchange");
      temp = temp.replace(/global/g, "custom");
      temp = temp.replace(/\Wdoc_id=[0-9]*/, "&doc_id=" + doc_id);
      $(element).attr("onchange", temp);
    }
    else{
      temp = element.attr("onchange");
      temp = temp.replace(/custom/g, "global");
      temp = temp.replace("global", "custom");
      temp = temp.replace(/\Wdoc_id=[0-9]*/, "&doc_id=0");
      $(element).attr("onchange", temp);
    }
  }
  else if(type == 'input'){
    element = row.children("td:last").children("input");
    if(label_class.indexOf("global") != -1){
      temp = element.attr("onchange");
      temp = temp.replace(/global/g, "custom");
      temp = temp.replace(/\Wdoc_id=[0-9]*/, "&doc_id=" + doc_id);
      $(element).attr("onchange", temp);
    }
    else{
      temp = element.attr("onchange");
      temp = temp.replace(/custom/g, "global");
      temp = temp.replace("global", "custom");
      temp = temp.replace(/\Wdoc_id=[0-9]*/, "&doc_id=0");
      $(element).attr("onchange", temp);
    }
  }
  else if(type == 'multiple'){
      $(row).children("td").each(function(i){
        if($(this).children("input").length > 0){
          element = $(this).children("input");
          if(label_class.indexOf("global") != -1){
            temp = element.attr("onchange");
            temp = temp.replace(/global/g, "custom");
            temp = temp.replace(/\Wdoc_id=[0-9]*/, "&doc_id=" + doc_id);
            $(element).attr("onchange", temp);
          }
          else{
            temp = element.attr("onchange");
            temp = temp.replace(/custom/g, "global");
            temp = temp.replace("global", "custom");
            temp = temp.replace(/\Wdoc_id=[0-9]*/, "&doc_id=0");
            $(element).attr("onchange", temp);
          }
        }
    });
  }
}

// function updatePosition(object, direction){
//   var row = $(object).parents("tr:first");
//   var tbody = $(object).parents("tbody");
//   var mover = parseInt(row.attr('id').replace("grantor", ""), 10);
//   var shaker = 0;
//   var temp = "";

//   if (direction == "up" && mover > 1) {
//       shaker = mover - 1;
//       row.prev().attr("id", "grantor" + mover);
//       row.prev().children("td:first").children("a").attr("href", row.prev().children("td:first").children("a").attr("href").replace("number=" + shaker, "number=" + mover));
//       row.prev().children("td:first").children("input").attr("onchange", row.prev().children("td:first").children("input").attr("onchange").replace("position=" + shaker, "position=" + mover));
//       row.prev().children("td:first").children("input").attr("id", row.prev().children("td:first").children("input").attr("id").replace(shaker, mover));

//       row.prev().children("td").eq(1).children("input").attr("id", row.prev().children("td").eq(1).children("input").attr("id").replace(shaker, mover));
//       row.prev().children("td").eq(1).children("input").attr("onchange", row.prev().children("td").eq(1).children("input").attr("onchange").replace("position=" + shaker, "position=" + mover));

//       row.prev().children("td:last").children("img:first").attr("onclick", row.prev().children("td:last").children("img:first").attr("onclick").replace("position=" + shaker, "position=" + mover));
//       row.prev().children("td:last").children("img:last").attr("onclick", row.prev().children("td:last").children("img:last").attr("onclick").replace("position=" + shaker, "position=" + mover));

//       row.attr("id", "grantor" + shaker);
//       row.children("td:first").children("a").attr("href", row.children("td:first").children("a").attr("href").replace("number=" + mover, "number=" + shaker));
//       row.children("td:first").children("input").attr("onchange", row.children("td:first").children("input").attr("onchange").replace("position=" + mover, "position=" + shaker));
//       row.children("td:first").children("input").attr("id", row.children("td:first").children("input").attr("id").replace(mover, shaker));

//       row.children("td").eq(1).children("input").attr("id", row.children("td").eq(1).children("input").attr("id").replace(mover, shaker));
//       row.children("td").eq(1).children("input").attr("onchange", row.children("td").eq(1).children("input").attr("onchange").replace("position=" + mover, "position=" + shaker));

//       row.children("td:last").children("img:first").attr("onclick", row.children("td:last").children("img:first").attr("onclick").replace("position=" + mover, "position=" + shaker));
//       row.children("td:last").children("img:last").attr("onclick", row.children("td:last").children("img:last").attr("onclick").replace("position=" + mover, "position=" + shaker));

//       row.insertBefore(row.prev());
//   } else if(direction == "down" && mover != tbody.children("tr").length) {
//       shaker = mover + 1;

//       row.next().attr("id", "grantor" + mover);
//       row.next().children("td:first").children("a").attr("href", row.next().children("td:first").children("a").attr("href").replace("number=" + shaker, "number=" + mover));
//       row.next().children("td:first").children("input").attr("onchange", row.next().children("td:first").children("input").attr("onchange").replace("position=" + shaker, "position=" + mover));
//       row.next().children("td:first").children("input").attr("id", row.next().children("td:first").children("input").attr("id").replace(shaker, mover));

//       row.next().children("td").eq(1).children("input").attr("id", row.next().children("td").eq(1).children("input").attr("id").replace(shaker, mover));
//       row.next().children("td").eq(1).children("input").attr("onchange", row.next().children("td").eq(1).children("input").attr("onchange").replace("position=" + shaker, "position=" + mover));

//       row.next().children("td:last").children("img:first").attr("onclick", row.next().children("td:last").children("img:first").attr("onclick").replace("position=" + shaker, "position=" + mover));
//       row.next().children("td:last").children("img:last").attr("onclick", row.next().children("td:last").children("img:last").attr("onclick").replace("position=" + shaker, "position=" + mover));

//       row.attr("id", "grantor" + shaker);
//       row.children("td:first").children("a").attr("href", row.children("td:first").children("a").attr("href").replace("number=" + mover, "number=" + shaker));
//       row.children("td:first").children("input").attr("onchange", row.children("td:first").children("input").attr("onchange").replace("position=" + mover, "position=" + shaker));
//       row.children("td:first").children("input").attr("id", row.children("td:first").children("input").attr("id").replace(mover, shaker));

//       row.children("td").eq(1).children("input").attr("id", row.children("td").eq(1).children("input").attr("id").replace(mover, shaker));
//       row.children("td").eq(1).children("input").attr("onchange", row.children("td").eq(1).children("input").attr("onchange").replace("position=" + mover, "position=" + shaker));

//       row.children("td:last").children("img:first").attr("onclick", row.children("td:last").children("img:first").attr("onclick").replace("position=" + mover, "position=" + shaker));
//       row.children("td:last").children("img:last").attr("onclick", row.children("td:last").children("img:last").attr("onclick").replace("position=" + mover, "position=" + shaker));


//       row.insertAfter(row.next());
//   }
//}

function changeFormatOptions(object){
  if(object.value == "both"){
    $("#signature_format").html("<option value='grantorfirst' selected='selected'>Grantor First</option><option value='granteefirst'>Grantee First</option>");
    $("#signature_format").change();
  }
  else{
    $("#signature_format").html("<option value='left' selected='selected'>Left</option><option value='right'>Right</option><option value='both'>Both</option>");
    $("#signature_format").change();
  }
}

function amountToUSD(value) {
  if(value != ""){
    var number = value.toString().replace(/,/g, ''),
    dollars = number.split('.')[0],
    cents = (number.split('.')[1] || '') +'00';
    dollars = dollars.split('').reverse().join('')
        .replace(/(\d{3}(?!$))/g, '$1,')
        .split('').reverse().join('');
    return dollars + '.' + cents.slice(0, 2);
  }
}

function destroyDisbursement(object){
  var row = $(object).closest('tr');
  addToQueue('remove_payment', 'application/flash_notice?notice=Are you sure you want to remove this disbursement?&confirm=Yes&post=/check_workings/destroy?id=' + $(row).attr("id").replace("disbursement_", "") );
}

function addFileEntity(file_id, entity_id) {
  position = $(this).parents("tr").find("[id^=position_]").first().val();
  $.ajax({
    url: "/index/" + file_id + "/file_entities?entity_id=" + entity_id + "&position=" + position,
    type: "POST"
  });
}

function toggle_payment_window(object, id, table){
  if($(object).next().length == 0 || $(object).next().attr('class').indexOf('tru_payment_window') == -1){
    $.get(table + '/' + id + '/view_payments?view=overlay');
  }
  else{
    $('#payment_results .tru_payment_window').remove();
  }
}
