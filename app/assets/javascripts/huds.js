$(document).ready(function() {
  $( ".date_short").not('hasDatePicker').datepicker({
      changeMonth: true,
      changeYear: true
    });

    $( "#datepicker, .datepicker").not('hasDatePicker').datepicker({
      changeMonth: true,
      changeYear: true
    });

  $( "#hud input[name='payee_name'], #hud input[data-type=payee_name]" ).autocomplete({
    source: Routes.gather_contacts_index_path({ id: $("#hud").attr('data-fileid')}),
  });

  $("div#hud input[type=text]").unbind(".arrow_nav").on("keydown.arrow_nav", function(event){
    if($(this).attr('name') == "payee_name" && (event.keyCode == 38 || event.keyCode == 40)){
      return;
    }

    // LEFT
    // if(event.keyCode == 37){
    //   index = $(this).closest('div#hud').find("input[type=text]").index(this) - 1;
    //   $(this).closest('div#hud').find('input[type=text]').eq(index).focus();
    //   return;
    // }

    // RIGHT
    // else if(event.keyCode == 39){
    //   index = $(this).closest('div#hud').find("input[type=text]").index(this) + 1;
    //   $(this).closest('div#hud').find('input[type=text]').eq(index).focus();
    //   return;
    // }

    // UP
    if(event.keyCode == 38){
      index = $(this).closest('tr').find("input:enabled[type=text]").index(this);
      row_index = $(this).closest('div#hud').find('tr').index($(this).closest('tr'));
      move = $(this).closest('div#hud').find('tr').eq(row_index - 1).find('input[type=text]').not(':disabled').eq(index);

      while(row_index >= 0 && $(move).length < 1 ){
        row_index -= 1;
        move = $(this).closest('div#hud').find('tr').eq(row_index).find('input[type=text]').not(':disabled').eq(index);

        if( $(move).length < 1 ){
          move = $(this).closest('div#hud').find('tr').eq(row_index).find('input[type=text]').not(':disabled').last();
        }
      }
    }

    // DOWN, ENTER
    else if(event.keyCode == 40 || event.keyCode == 13){
      index = $(this).closest('tr').find("input:enabled[type=text]").index(this);
      row_index = $(this).closest('div#hud').find('tr').index($(this).closest('tr'));
      move = $(this).closest('div#hud').find('tr').eq(row_index + 1).find('input[type=text]').not(':disabled').eq(index);

      while(row_index  < $(this).closest('div#hud').find('tr').length && $(move).length < 1 ){
        row_index += 1;
        move = $(this).closest('div#hud').find('tr').eq(row_index).find('input[type=text]').not(':disabled').eq(index);

        if( $(move).length < 1 ){
          move = $(this).closest('div#hud').find('tr').eq(row_index).find('input[type=text]').not(':disabled').last();
        }
      }
    }

    if(event.keyCode == 38 || event.keyCode == 40 || event.keyCode == 13){
      if( $(move).length > 0 ){
        $(move).focus();
      }
    }
  });

  $("div#hud .line_total input[type=text]").unbind(".arrow_nav").on("keydown.arrow_nav", function(event){
    // LEFT
    // if(event.keyCode == 37){
    //   index = $(this).closest('div#hud').find("input[type=text]").index(this) - 1;
    //   $(this).closest('div#hud').find('input[type=text]').eq(index).focus();
    //   return;
    // }

    // RIGHT
    // else if(event.keyCode == 39){
    //   index = $(this).closest('div#hud').find("input[type=text]").index(this) + 1;
    //   $(this).closest('div#hud').find('input[type=text]').eq(index).focus();
    //   return;
    // }
    // UP
    if(event.keyCode == 38){
      index = $(this).closest("tr").find(".line_total input[type=text]").index(this);
      row_index = $(this).closest('div#hud').find("tr").index($(this).closest("tr"));
      move = $(this).closest('div#hud').find("tr").eq(row_index - 1).find('.line_total input[type=text]').not(':disabled').eq(index);

      while(row_index >= 0 && $(move).length < 1 ){
        row_index -= 1;
        move = $(this).closest('div#hud').find("tr").eq(row_index).find('.line_total input[type=text]').not(':disabled').eq(index);

        if( $(move).length < 1 ){
          move = $(this).closest('div#hud').find("tr").eq(row_index).find('.line_total input[type=text]').not(':disabled').last();
        }
      }
    }

    // DOWN, ENTER
    else if(event.keyCode == 40 || event.keyCode == 13){
      index = $(this).closest("tr").find(".line_total input[type=text]").index(this);
      row_index = $(this).closest('div#hud').find("tr").index($(this).closest("tr"));
      move = $(this).closest('div#hud').find("tr").eq(row_index + 1).find('.line_total input[type=text]').not(':disabled').eq(index);

      while(row_index < $(this).closest('div#hud').find("tr").length && $(move).length < 1 ){
        row_index += 1;
        move = $(this).closest('div#hud').find("tr").eq(row_index).find('.line_total input[type=text]').not(':disabled').eq(index);

        if( $(move).length < 1 ){
          move = $(this).closest('div#hud').find("tr").eq(row_index).find('.line_total input[type=text]').not(':disabled').last();
        }
      }

      if($(move).length < 1){
        index = $(this).closest("tr").find("input[type=text]").index(this);
        row_index = $(this).closest('div#hud').find("tr").index($(this).closest("tr"));
        move = $(this).closest('div#hud').find("tr").eq(row_index + 1).find('input[type=text]').not(':disabled').eq(index);

        while(row_index < $(this).closest('div#hud').find("tr").length && $(move).length < 1 ){
          row_index += 1;
          move = $(this).closest('div#hud').find("tr").eq(row_index).find('input[type=text]').not(':disabled').eq(index);

          if( $(move).length < 1 ){
            move = $(this).closest('div#hud').find("tr").eq(row_index).find('input[type=text]').not(':disabled').last();
          }
        }
      }
    }

    if(event.keyCode == 38 || event.keyCode == 40 || event.keyCode == 13){
      if( $(move).length > 0 ){
        $(move).focus();
      }
    }
  });

  $("div#hud input[type=text]").on("focus", function(){
    if($(this).attr('class') == undefined || $(this).attr('class').indexOf("hasDatepicker") == -1){
      $("#ui-datepicker-div").hide();
    }

    $(this).select();
  });
});

$(document).ready(function() {
  $('.currency').blur(function() {
    $('input.currency').formatCurrency($.extend({ symbol: '' }));
  });
});

$(document).ready(function() {
  $('.currency').blur(function () {
    var sum = 0;
    $('.currency').each(function() {
      sum += Number($(this).val().replace(/,/gi, ''));
    });
    // here, you have your sum
  });
});

function updateLine(object,line_id,hud_id,field){
  var payee_id = "";
  value = object.value.toString().replace(/,/g,'')
  value = parseFloat(value);
  if (isNaN(value)){
    value = ""
  }
  if (value != "" && ["start_date", "end_date", "periods", "description", "name", "percent", "payee_name", "daily_interest"].indexOf(field) == -1){
    // object.value = addCommas(value.toFixed(2));
    toUSN(object);
  }
  else if(field == "daily_interest"){
    if(value != ""){
      object.value = addCommas(value.toFixed(4));
    }
  }
  else if (field == "percent"){
    if(value != ""){
      object.value = addCommas(value.toFixed(3));
    }
  } else {
    value = object.value;
    if(value.toString() == "0" && field != "periods"){
      toUSN(object);
    }
  }

  $.ajaxq("hud_lines",{
    url: "/huds/" + hud_id + "/hud_lines/" + line_id + "?field=" + field + "&value=" + encodeURIComponent(value),// + add,
    type: "put"
  });
}

function displayFlyout(line){
  if($("#hud_row_" + line + " .submenu_show").html() == undefined){
    if($(".submenu_show").html() != undefined){
      $(".submenu_show").attr("class", "submenu_hide");
    }

    $("#hud_row_" + line + " .submenu_hide").attr("class", "submenu_show");
  }
  else{
    $("#hud_row_" + line + " .submenu_show").attr("class", "submenu_hide");
  }
}

function updateWallet(line, hud){
  addToQueue('update_wallet', 'hud_lines/' + line + '/update_wallet?hud_id=' + hud);
}

function addCommas(nStr){
  nStr += '';
  x = nStr.split('.');
  x1 = x[0];
  x2 = x.length > 1 ? '.' + x[1] : '';
  var rgx = /(\d+)(\d{4})/;
  while (rgx.test(x1)) {
    x1 = x1.replace(rgx, '$1' + ',' + '$2');
  }
  return x1 + x2;
}

function updateCalculated(group,object,line_id,hud_id,field){
  id = object.id
  value = object.value.toString().replace(/,/g,'')
  value = parseFloat(value);
  if (isNaN(value)){
    value = ""
  }

  if (value != "" && field != "start_date" && field != "end_date" && field != "periods" && field != "description" && field != "name"){
    // object.value = addCommas(value.toFixed(2));
    toUSN(object);
  } else {
    value = object.value;
    if(value.toString() == "0" && field != "periods"){
      toUSN(object);
    }
  }
  $("#" + id).css("color","#D2691E");

  $.ajaxq("hud_lines",{
    url: "/huds/" + hud_id + "/hud_lines/" + line_id + "?field=" + field + "&value=" + value + "&group=" + group,
    type: "put"
  });
}

function revertCalculated(object,line_id,hud_id,field){
  id = object.id
  value = object.value.toString().replace(/,/g,'')
  value = parseFloat(value);
  if (isNaN(value)){
    value = ""
  }

  if (value != "" && field != "start_date" && field != "end_date" && field != "periods" && field != "description" && field != "name"){
    // object.value = addCommas(value.toFixed(2));
    toUSN(object);
  } else {
    value = object.value;
    if(value.toString() == "0" && field != "periods"){
      toUSN(object);
    }
  }

  $("#" + id).css("color","blue");

  $.ajaxq("hud_lines",{
    url: "/huds/" + hud_id + "/hud_lines/" + line_id + "?field=" + field + "&value=" + value + "&group=nil",
    type: "put"
  });
}

function updateLoanTerms(sender){
  $.ajax({
    url: 'huds/' + $("#hud").attr("data-hudid") + '?field=' + $(sender).attr('name') + '&value=' + encodeURIComponent( $(sender).val() ),
    type: "put"
  });
  var to_currency = ["initial_loan_amount", "initial_payment_amount", "maximum_balance", "monthly_payment_amount", "maximum_payment_amount", "maximum_prepayment_penalty", "balloon_payment_amount", "escrow_payment_amount", "total_payment_amount"];

  if(to_currency.indexOf( $(sender).attr('name') ) != -1 && !isNaN( $(sender).val() )){
    toUSN(sender);
  }
}

//$(function() {
//  $('input#datepicker').dateinput();
//});
