require 'jcode' if RUBY_VERSION < '1.9'
require File.join(File.expand_path(File.dirname(__FILE__)), "wikicloth", "core_ext")
require File.join(File.expand_path(File.dirname(__FILE__)), "wikicloth", "wiki_buffer")
require File.join(File.expand_path(File.dirname(__FILE__)), "wikicloth", "wiki_link_handler")
require File.join(File.expand_path(File.dirname(__FILE__)), "wikicloth", "parser")
require File.join(File.expand_path(File.dirname(__FILE__)), "wikicloth", "section")
require File.join(File.expand_path(File.dirname(__FILE__)), "wikicloth", "token")
require File.join(File.expand_path(File.dirname(__FILE__)), "wikicloth", "lexer")
String.send(:include, ExtendedString)

module WikiCloth

  VERSION = "0.6.2"

  class WikiCloth

    def initialize(opt={})
      self.options[:link_handler] = opt[:link_handler] unless opt[:link_handler].nil?
      self.load(opt[:data],opt[:params]) unless opt[:data].nil?
    end

    def load(data,p={})
      depth = 1
      count = 0
      root = [self.sections]

      # parse wiki document into sections
      data.each_line do |line|
        if line =~ /^([=]{1,6})\s*(.*?)\s*(\1)/
          root << root.last[-1].children if $1.length > depth
          root.pop if $1.length < depth
          depth = $1.length
          root.last << Section.new(line, get_id_for($2.gsub(/\s+/,'_')))
          count += 1
        else
          root.last[-1] << line
        end
      end

      # if we find template variables assume document is
      # a template
      self.sections.first.template = true if data =~ /\{\{\{\s*([A-Za-z0-9]+)\s*\}\}\}/

      # If there are more than four sections enable automatic
      # table of contents
      self.sections.first.auto_toc = true unless count < 4 || data =~ /__(NO|)TOC__/

      self.params = p
    end

    def sections
      @sections ||= [Section.new]
    end

    def render(opt={})
      noedit = false
      self.params.merge!({ 'WIKI_VERSION' => ::WikiCloth::VERSION, 'RUBY_VERSION' => RUBY_VERSION })
      self.options = { :output => :html, :link_handler => self.link_handler, :params => self.params, :sections => self.sections }.merge(opt)
      self.options[:link_handler].params = options[:params]
      data = self.sections.collect { |s| s.render(self.options) }.join
      data.gsub!(/<!--(.|\s)*?-->/,"")
      data << "\n" if data.last(1) != "\n"
      buffer = WikiBuffer.new("",options)
      data.each_char { |c| buffer.add_char(c) }
      buffer.to_s
    end

    def to_html(opt={})
      self.render(opt)
    end

    def link_handler
      self.options[:link_handler] ||= WikiLinkHandler.new
    end

    def params
      @page_params ||= {}
    end

    protected
    def sections=(val)
      @sections = val
    end

    def get_id_for(val)
      val.gsub!(/[^A-Za-z0-9_]+/,'')
      @idmap ||= {}
      @idmap[val] ||= 0
      @idmap[val] += 1
      @idmap[val] == 1 ? val : "#{val}-#{@idmap[val]}"
    end

    def options=(val)
      @options = val
    end

    def options
      @options ||= {}
    end

    def params=(val)
      @page_params = val
    end

  end

end
