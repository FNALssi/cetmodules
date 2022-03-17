(async function() {
  'use strict';

  async function getVersions() {
    try {
      let res = await fetch(DOCUMENTATION_OPTIONS.URL_ROOT + '../versions.json');
      return await res.json();
    }
    catch(error) {
      console.log(error);
    }
  }

  var all_versions = await getVersions();

  function build_select(current_version, current_release) {
    let buf = ['<select>'];

    $.each(all_versions, function(version, title) {
      buf.push('<option value="' + version + '"');
      if (version == current_version) {
        buf.push(' selected="selected">');
        if (version[0] == 'v') {
          buf.push(current_release);
        } else {
          buf.push(title + ' (' + current_release + ')');
        }
      } else {
        buf.push('>' + title);
      }
      buf.push('</option>');
    });

    buf.push('</select>');
    return buf.join('');
  }

  function getDocumentBasePath() {
    let file = document.location.pathname.substring(document.location.pathname.lastIndexOf('/') + 1);
    let path = document.location.pathname.substring(0, document.location.pathname.lastIndexOf('/' + file));
    let parts = path.split(/\//);
    $.each(DOCUMENTATION_OPTIONS.URL_ROOT.split(/\//), function() {
      if (this === '..')
        parts.pop();
    });
    return parts.join('/');
  }

  function getRelativePath() {
    return document.location.pathname.substring(getDocumentBasePath().length);
  }

  function switch_to_version(new_version) {
    return DOCUMENTATION_OPTIONS.URL_ROOT + '../' + new_version + getRelativePath();
  }

  function on_switch() {
    let selected = $(this).children('option:selected').attr('value');
    if (selected != DOCUMENTATION_OPTIONS.VERSION) {
      let new_url = switch_to_version(selected)
      // check beforehand if url exists, else redirect to version's start page
      $.ajax({
        url: new_url,
        success: function() {
           window.location.href = new_url;
        },
        error: function() {
          window.location.href = DOCUMENTATION_OPTIONS.URL_ROOT + '../' + selected;
        }
      });
    }
  }

  $(document).ready(function() {
    let release = DOCUMENTATION_OPTIONS.VERSION;
    let url_base = getDocumentBasePath();
    let version = url_base.substring(url_base.lastIndexOf('/') + 1);
    let select = build_select(version, release);
    $('.version_switch_note').html('Or, select a version from the drop-down menu above.');
    $('.version_switch').html(select);
    $('.version_switch select').bind('change', on_switch);
  });
})();
