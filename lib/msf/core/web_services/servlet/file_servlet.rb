#
# Standard Library
#

module FileServlet
  def self.api_path
    '/api/v1/files'
  end

  def self.api_path_for_file
    "#{FileServlet.api_path}/file"
  end

  def self.api_path_for_dir
    "#{FileServlet.api_path}/dir"
  end

  def self.api_path_for_root
    "#{FileServlet.api_path}/root"
  end

  def self.api_path_for_search
    "#{FileServlet.api_path}/search"
  end

  def self.registered(app)
    app.get FileServlet.api_path_for_file, &file_download
    app.post FileServlet.api_path_for_file, &file_upload
    app.put FileServlet.api_path_for_file, &file_rename
    app.delete FileServlet.api_path_for_file, &file_delete

    app.get FileServlet.api_path_for_dir, &dir_entries
    app.post FileServlet.api_path_for_dir, &dir_mkdir
    app.put FileServlet.api_path_for_dir, &dir_rename
    app.delete FileServlet.api_path_for_dir, &dir_delete

    app.get FileServlet.api_path_for_root, &root_path
    app.get FileServlet.api_path_for_search, &search_file
  end
  #######

  #######
  # file
  def self.file_download
    lambda {
      warden.authenticate!
      sanitized_params = sanitize_params(params, env['rack.request.query_hash'])
      opts_path = sanitized_params[:path] || ''
      path = File.join(Msf::Config.rest_files_directory, opts_path)
      if get_db.safe_expand_path?(path) && File.exist?(path) && !File.directory?(path)
        send_file(path, buffer_size: 4096, stream: true)
      else
        result = { message: 'No such file' }
        set_json_data_response(response: result)
      end
    }
  end

  def self.file_upload
    lambda {
      warden.authenticate!
      sanitized_params = sanitize_params(params, env['rack.request.query_hash'])
      if sanitized_params[:file]
        opts_path = sanitized_params[:path] || ''
        path = File.join(Msf::Config.rest_files_directory, opts_path)
        temp_path = sanitized_params[:file][:tempfile].path
        if get_db.safe_expand_path?(path) && !File.exist?(path)
          FileUtils.mkdir_p(File.dirname(path))
          FileUtils.cp_r(temp_path, path)
          result = { path: path }
        else
          result = { message: 'The file already exists' }
        end
        FileUtils.rm_rf(temp_path) if File.exist?(temp_path)
      else
        result = { message: 'Please upload a file' }
      end
      set_json_data_response(response: result)
    }
  end

  def self.file_delete
    lambda {
      warden.authenticate!
      opts = parse_json_request(request, true)
      opts_path = opts[:path] || ''
      path = File.join(Msf::Config.rest_files_directory, opts_path)
      if !get_db.rest_files_directory?(path) && !File.directory?(path) && get_db.safe_expand_path?(path)
        FileUtils.rm_rf(path)
        result = { path: path }
      else
        result = { message: 'No such file' }
      end
      set_json_data_response(response: result)
    }
  end

  def self.file_rename
    lambda {
      warden.authenticate!
      opts = parse_json_request(request, true)
      opts_path = opts[:path] || ''
      opts_new_path = opts[:new_path] || ''
      path = File.join(Msf::Config.rest_files_directory, opts_path)
      new_path = File.join(Msf::Config.rest_files_directory, opts_new_path)
      if (!File.directory?(path) && get_db.safe_expand_path?(path)) && File.exist?(path) \
        && (!File.directory?(new_path) && get_db.safe_expand_path?(new_path))
        FileUtils.mv(path, new_path)
        result = { path: new_path }
      else
        result = { message: 'No such file' }
      end
      set_json_data_response(response: result)
    }
  end

  # dir
  def self.dir_entries
    lambda {
      warden.authenticate!
      sanitized_params = sanitize_params(params, env['rack.request.query_hash'])
      opts_path = sanitized_params[:path] || ''
      path = File.join(Msf::Config.rest_files_directory, opts_path)
      if get_db.safe_expand_path?(path) && File.directory?(path)
        result = get_db.list_local_path(path)
      else
        result = { message: 'No such directory' }
      end
      set_json_data_response(response: result)
    }
  end

  def self.dir_mkdir
    lambda {
      warden.authenticate!
      opts = parse_json_request(request, true)
      opts_path = opts[:path] || ''
      path = File.join(Msf::Config.rest_files_directory, opts_path)
      if get_db.safe_expand_path?(path)
        FileUtils.mkdir_p(path)
        result = { path: path }
      else
        result = { message: 'Failed to create folder' }
      end
      set_json_data_response(response: result)
    }
  end

  def self.dir_delete
    lambda {
      warden.authenticate!
      opts = parse_json_request(request, true)
      opts_path = opts[:path] || ''
      path = File.join(Msf::Config.rest_files_directory, opts_path)
      if !get_db.rest_files_directory?(path) && get_db.safe_expand_path?(path) && File.directory?(path)
        FileUtils.rm_rf(path)
        result = { path: path }
      else
        result = { message: 'No such directory' }
      end
      set_json_data_response(response: result)
    }
  end

  def self.dir_rename
    lambda {
      warden.authenticate!
      opts = parse_json_request(request, true)
      opts_path = opts[:path] || ''
      opts_new_path = opts[:new_path] || ''
      path = File.join(Msf::Config.rest_files_directory, opts_path)
      new_path = File.join(Msf::Config.rest_files_directory, opts_new_path)
      if (!get_db.rest_files_directory?(path) && get_db.safe_expand_path?(path) && File.directory?(path)) \
        && (!get_db.rest_files_directory?(new_path) && get_db.safe_expand_path?(new_path))
        FileUtils.mv(path, new_path)
        result = { path: new_path }
      else
        result = { message: 'No such directory' }
      end
      set_json_data_response(response: result)
    }
  end

  # root
  def self.root_path
    lambda {
      warden.authenticate!
      result = { path: File.expand_path(Msf::Config.rest_files_directory) + File::SEPARATOR }
      set_json_data_response(response: result)
    }
  end

  # search
  def self.search_file
    lambda {
      warden.authenticate!
      sanitized_params = sanitize_params(params, env['rack.request.query_hash'])
      opts_path = sanitized_params[:path] || ''
      search_term = sanitized_params[:search_term] || ''
      path = File.join(Msf::Config.rest_files_directory, opts_path)
      search_file_paths = []
      utf8_buf = search_term.dup.force_encoding('UTF-8')
      # Return search keywords file path
      if utf8_buf.valid_encoding? && get_db.safe_expand_path?(path) && File.directory?(path)
        regex = Regexp.new(Regexp.escape(utf8_buf), true)
        Find.find(path) do |file_path|
          search_file_paths << file_path if (file_path =~ regex) && !File.directory?(file_path)
        end
        result = { path: search_file_paths }
      else
        result = { message: 'Invalid parameter' }
      end
      set_json_data_response(response: result)
    }
  end
end
