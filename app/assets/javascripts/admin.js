var destroyRule, removeRule, remove_rule_name_exception, update_rule_name_exception_position;

$(function(){
  $("#user_results tr").on("click", function(){
    $("#user_detail").html("<p class='no_result'>Loading User...</p>");
  });

  $("#rules_search_result tr").on("click", function(){
    $("#rules_show").html("<p class='no_result'>Loading Rule...</p>");
  });
});

$(".pref").on("click", function() {
  return $.get("admin/site_preferences/" + $(this).attr("value") + "/set_preference.js");
});

jQuery(function() {
  $("form").on("click", ".remove_fields", function(event) {
    $(this).prev("input[type=hidden]").val("1");
    $(this).closest("fieldset").hide();
    return event.preventDefault();
  });
  return $("form").on("click", ".add_fields", function(event) {
    var regexp, time;
    regexp = void 0;
    time = void 0;
    time = new Date().getTime();
    regexp = new RegExp($(this).data("id"), "g");
    $(this).before($(this).data("fields").replace(regexp, time));
    return event.preventDefault();
  });
});

$(document).on("click", "#search_results tbody tr", function() {
  $("tr.active_row").removeClass("active_row");
  $(this).toggleClass("active_row");
  return $.get("admin/" + $(this).attr("controller") + "/" + $(this).attr("id") + "/result_detail.js");
});

destroyRule = function(object) {
  $.ajax({
    url: "rules/" + $(object).closest("tr").attr("id").replace("rule_", ""),
    type: "DELETE",
    success: removeRule(object)
  });
};

removeRule = function(object) {
  $(object).closest("tr").remove();
  if ($("#rules_search_result").find("tr").length === 0) {
    showZeroResults("rules_search_result");
    $("#rules_show").html("<p class='no_result'>No rule selected.</p>");
  } else {
    if ($("#rules_search_result").find(".active_row").length < 1) {
      $("#rules_search_result").find("tr").eq(0).click();
    }
  }
};

remove_rule_name_exception = function(object, type) {
  if ($(object).closest("tbody").find("tr").length <= 1) {
    $(object).closest("tbody").html("<tr class='no_result'><td>No " + type + "</td></tr>");
  } else {
    $(object).closest("tr").remove();
  }
  update_rule_name_exception_position();
};

update_rule_name_exception_position = function() {
  var containers, i, number;
  number = 0;
  containers = ["overlay_rule_names", "overlay_rule_exceptions"];
  i = 0;
  while (i < containers.length) {
    $("#" + containers[i]).find("tr").each(function() {
      number = $("#" + containers[i] + " tr").index(this);
      $(this).attr("id", number);
      return $(this).find("input, select").each(function() {
        return $(this).attr("name", containers[i].replace("overlay_", "") + "[" + number + "[" + $(this).attr("field") + "]]");
      });
    });
    i++;
  }
};

function editPermission(user_id, company, object){
    if(company == "NULL"){
      company = ""
    }
    if(object.checked == true){
      var action = "add"
    } else{
      var action = "remove"
    }
    $.ajaxq("permissions",{
      url: "admin/users/" + user_id + "/edit_permission?do=" + action + "&permission=" + $(object).val() + "&company=" + company,
      method: "put"
    })
  }

function editPreference(user_id, site_preference_id){
  return $.ajax({url: "admin/users/" + user_id + "/set_user_preference?site_preference_id=" + site_preference_id, type: "put"});
}

function editCompany(user_id, object){
  if(object.checked == true){
    var action = "add"
  } else{
    var action = "remove"
  }
  $.ajaxq("companies",{
    url: "admin/users/" + user_id + "/edit_company?do=" + action + "&company_id=" + $(object).val(),
    method: "put"
  })
}

function selectCompany(value){
  $(".user_tab").hide();
  $("#" + value).show();
}
