(async function() {
  'use strict';

  const content_root = document.documentElement.dataset.content_root;

  async function getVersions() {
    try {
      let res = await fetch(content_root + '../versions.json');
      return await res.json();
    }
    catch(error) {
      console.log(error);
    }
  }

  var all_versions = await getVersions();

  function is_numeric_version(version) {
    return /^v?[0-9]+(?:\.[0-9]+)?/.test(version);
  }

  function build_select(current_version, current_release) {
    let buf = ['<select>'];
    all_versions['ordered-versions'].forEach(function(version) {
      var title = all_versions['version-entries'][version]['display-name'];
      buf.push('<option value="' + title + '"');
      if (title == current_version) {
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
    $.each(content_root.split(/\//), function() {
      if (this === '..')
        parts.pop();
    });
    return parts.join('/');
  }

  function getRelativePath() {
    return document.location.pathname.substring(getDocumentBasePath().length);
  }

  function switch_to_version(new_version) {
    return content_root + '../' + new_version + getRelativePath();
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
          window.location.href = content_root + '../' + selected;
        }
      });
    }
  }

  $(document).ready(function() {
    let release = DOCUMENTATION_OPTIONS.VERSION;
    let url_base = getDocumentBasePath();
    let version = url_base.substring(url_base.lastIndexOf('/') + 1);
    let select = build_select(version, release);

    var latest_version = all_versions['latest-version'] || null;
    // Only show "outdated-version" blocks if they're applicable.
    if (!is_numeric_version(version) ||
        (latest_version &&
         version == all_versions['version-entries'][latest_version]['display-name'])) {
      $.each(document.getElementsByClassName('outdated'), function() {
        this.style.display = 'none';
      });
    }
    $('.version_switch_note').html('Or, select a version from the drop-down menu above.');
    $('.version_switch').html(select);
    $('.version_switch select').bind('change', on_switch);
  });
})();
