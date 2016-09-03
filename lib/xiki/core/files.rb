# -*- coding: utf-8 -*-
module Xiki
  class Files

    def self.menu
      "
      - @edited/
      - @current/
      - tree) @Buffers.tree 25/
      - .history/
      - docs/
        > Summary
        | The 'files' menu deals with navigating the filesystem.
        |
        - keys/
          > Navigating
          | open+tree - navigate the files in a bookmarked dir
          |   (type '/' for the root)
          | search+bookmark - searches file contents in a bookmarked dir
          |
          > Recent Files
          | open+current - Show files currently open
          | open+edited - Show files recently edited
          | open+history - Show files recently open
          |
          > Saving
          | as+file - saves the file
          |   (using the normal emacs shortcut won't update the difflog)
          |
          > File Trees
          | do+name+file
          |   Renames a file (the file in a tree that the cursor is on).
          |
          | do+kill+file
          |   Deletes a file (the file in a tree that the cursor is on).
          |
          | do+copy+to
          |   Copies a file in the filesystem.  Used in a tree.  To use:
          |
          |   - 1) Put the cursor on a file in a tree
          |   - 2) do as+spot to remember that's the file you want to copy
          |   - 3) Put cursor on a file you want to copy it to
          |     - If you don't want to over-write an existing file
          |       - add the filename to the tree that you want to exist
          |   - 4) Type do+copy+to
          |
          > See
          @diff_log/docs/
      "
    end

    @@dir_hash = {
      'j' => '.js',
      'r' => '.rb',
      's' => '/spec/',
      'a' => '/app/',
      'm' => '/app/models/',
      'v' => '/app/views/',
      'c' => '/app/controllers/',
      'n' => '.notes',
      }

    # Lets user open a file
    def self.open
      return View.open $el.read_file_name("Open: ") if Keys.prefix_u
      View.open $el.read_file_name("Open: ", "/")
    end

    def self.open_sudo
      $el.find_file "/sudo:root@localhost:#{View.file || View.dir}"
    end

    def self.save
      # If prefix, save as
      if $el.elvar.current_prefix_arg
        $el.write_file $el.read_file_name("Save as: ")
      # Otherwise, difflog save
      else
        $el.difflog_save
      end
      # Refresh
      self.refresh_me_and_next_dired
    end

    def self.copy
      from = Files.file_name

      View.next
      to = View.dir
      View.previous
      if Keys.prefix_u?
        $el.rename_file(from, to)
      elsif Keys.prefix_uu
        command = "cp -R \"#{from}\" \"#{to}\""
        Shell.run command, :sync => true
      else
        $el.copy_file(from, to)
      end

      # Refresh
      self.refresh_me_and_next_dired
    end

    def self.zip
      #from = Files.file_name(:path => true)
      from = Files.file_name
      $el.other_window 1;  to = $el.elvar.default_directory;  $el.other_window -1
      if Keys.prefix_u?
        command = "unzip -d \"#{to}\" \"#{from}\""
      else
        command = "zip -r \"#{to}#{from}.zip\" \"#{from}\""
      end
      $el.message command
      $el.shell_command command
    end

    # Name of file without path or extension
    #
    # Files.stem
    def self.stem options={}
      self.file_name.sub(/\.[^.]+$/, '')
    end


    # Name of file without path
    #
    # Files.file_name
    def self.file_name options={}
      if options[:path]
        return $el.buffer_file_name || $el.dired_get_filename #'no_dir
      end
      if $el.buffer_file_name
        return $el.file_name_nondirectory($el.buffer_file_name)
      end
      $el.dired_get_filename(:no_dir)
    end

    def self.refresh_me_and_next_dired
      $el.revert_buffer(true, true, true) if($el.elvar.dired_directory)
      $el.other_window 1
      $el.revert_buffer(true, true, true) if($el.elvar.dired_directory)
      $el.other_window -1
    end

    def self.open_tail
      file = Tree.file :at_cursor=>1

      # If cursor is on a file tree, use it...

      if ! file || Keys.prefix_u
        bm = Keys.input(:timed=>true, :prompt=>"Enter bookmark of file to tail (or period for current file): ")
        file = (bm == ".") ? View.file : Bookmarks[":#{bm}"]
      end

      Shell.run "tail -f #{file}", :buffer => "*tail of #{file}"
    end

    def self.edited_array
      DiffLog.file_list
    end

    def self.current times=nil
      Buffers.tree times
    end

    def self.history_array
      $el.elvar.recentf_list.to_a
    end

    def self.history_tree times=nil
      times ||= History.prefix_times
      puts CodeTree.tree_search_option + Tree.paths_to_tree(history_array[0..(times-1)])
    end

    def self.open_just
      key = Keys.input(:prompt => "Open just currently open files of type (enter a letter): ", :chars=>1)
      dir = @@dir_hash[key]
      return message("No dir matching '#{key}' found.  See Files\#@@dir_hash") unless dir
      if Keys.prefix_u?
        Keys.clear_prefix
        Launcher.open("- Files.edited(100, :dir => '#{dir}')/")
      else
        Launcher.open("- Buffers.tree(0, :dir => '#{dir}')/")
      end
    end

    def self.open_last
      key = Keys.input(:prompt => "Open just currently open files of type (enter a letter): ", :chars=>1)
      dir = @@dir_hash[key]
      View.open Files.edited_array.grep((Regexp.new(Regexp.escape(dir)))).first
    end

    def self.open_edited
      case Keys.prefix
      when :u, 8;  Launcher.open("edited/tree/")
      else  Launcher.open("edited/")
      end
    end

    def self.open_history
      case Keys.prefix
      when nil;  Keys.prefix = nil; Launcher.open("- Files.history/")
      when 0;  Launcher.open("- Files.history_tree/")
      when :u;  Launcher.open("- Files.history_tree 7/")
      else  Launcher.open("- Files.history_tree #{Keys.prefix}/")
      end
    end

    def self.open? name
      $el.buffer_list.find{|b| $el.buffer_file_name(b) == name}
    end

    def self.open_in_os path=nil

      # If we're in a file tree, use path

      if path.nil? && FileTree.handles?
        path = Tree.path[-1]
      end

      path ||= View.file
      path ||= View.dir

      path = Bookmarks[path]

      # TODO: make this multi-platform > Equivalent command for linux?

      `open \"#{path}\"`
    end

    def self.do_load_file

      if View.name == "diff with saved/"   # If viewing diff, close it and save the actual file...
        file = View.txt[/.+\n.+/].sub("\n  - ", "")
        View.kill

        # Way to move to the buffer that doesn't show warnings
        $el.set_buffer $el.get_file_buffer(file)
      end

      $el.revert_buffer(true, true, true) rescue nil

      View.message "Reverted file"
      return if ! Keys.prefix_u

      View.flash $el.auto_revert_mode ? "- Enabled Auto-revert!" : "- Disabled Auto-revert!"
    end

    def self.do_clean_quotes
      with(:save_excursion) do
        $el.clean_crazy_quotes
      end
    end

    def self.enter_file
      message = "File to insert: "

      View.flash message
      path = Keys.input "#{message}: ", :timed=>1

      # They typed a word, so expand it as a bookmark
      path = Bookmarks[":#{path}"] if path =~/^\w/
      path = File.expand_path path

      is_dir = File.directory? path
      path = FileTree.add_slash_maybe path if is_dir

      View.insert path

    end

    # This is currently mac-specific
    def self.open_last_screenshot

      dirs = `ls -t #{Bookmarks[":dt"]}`
      screenshot = Bookmarks[":dt"]+dirs[/.+/]

      self.open_as screenshot, "Adobe Illustrator"

    end

    # This is currently mac-specific
    def self.open_as file, application
      command = "open -a \"#{application}\" \"#{file}\""

      $el.shell_command(command)
    end

    def self.open_in_window file=nil

      file ||= FileTree.tree_path_or_this_file

      file = File.expand_path Bookmarks[file]

      # Else, reveal current file
      command = "open --reveal \"#{file}\""
      $el.shell_command(command)

      nil
    end

    def self.dir_of path
      if File.directory? path
        path =~ /\/$/ ? path : "#{path}/"
      else
        path[/.+\//]
      end
    end

    def self.append path, txt

      return if View.name =~ /_log.notes$/
      path = File.expand_path path
      txt = "#{txt.strip}\n"
      File.open(path, "a") { |f| f << txt }
    end

    # Returns contents of a dir.  Just a wrapper around Dir.entries that removes "." and ".."
    def self.in_dir path
      Dir.entries(path).select{|o| o !~ /^\.+$/}
    end

    def self.open_nth nth
      prefix = Keys.prefix  # :clear=>1

      prefix == :u ?
        View.open(":t") :
        View.open(":n")

      if nth != 0
        View.to_highest
        nth.times { Move.to_quote }
      end

      Effects.blink if View.list.length > 1
      Launcher.launch
    end

    def self.delete_current_file

      dest_path = View.file
      return View.beep("- There's no file for this buffer!") if ! dest_path

      return unless View.confirm message="Delete current file (#{View.name})?", :times=>4

      command = "rm \"#{dest_path}\""

      result = Shell.run command, :sync=>true
      if (result||"").any?
        View.beep
        View.message "#{result}"
        return
      end

      return View.kill

    end

    if /^1\.9/===RUBY_VERSION
      def self.encoding_binary
        [{:binmode=>true}]
      end
    else
      def self.encoding_binary
        []
      end
    end

    # Returns a unique version of the filename.
    # Appends ".1" if the filename already exists.
    # Or, if that already exists, ".2" or ".3" etc.
    # Files.unique_name "/etc/passwd"
    #   /etc/passwd2
    def self.unique_name path
      return path if ! File.exists? path
      i, limit = 2, 1000

      extension = path.slice! /\.[a-z]+$/i
      while i < limit
        break if ! File.exists? "#{path}#{i}#{extension}"
        i += 1
      end
      "#{path}#{i}#{extension}"
    end

    # Replaces home with tilda
    # Files.tilda_for_home "/Users/craig/projects/"

    # Todo > fix spelling mistake > "tilda" -> "tilde"

    def self.tilda_for_home path, options={}

      home = ENV['HOME']
      return path if ! home

      path = path.sub(/\A#{Regexp.quote home}/, "~")
      path.gsub!(' ', '\ ') if options[:escape]
      path
    end

  end
end
