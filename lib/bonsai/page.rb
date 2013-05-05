require 'yaml'

if RUBY_VERSION =~ /^1.9./
  YAML::ENGINE.yamler = 'syck'
end

require 'tilt'
require 'liquid'
# jms mod
require 'slim'
require 'haml'
require 'active_support/inflector'

begin 
  require 'rdiscount'
  BlueCloth = RDiscount
rescue LoadError
  require 'maruku'
end

module Bonsai
  class Page
    class NotFound < StandardError; end;
    class << self
      attr_accessor :path, :pages
      
      def pages; @pages || {} end
      
      def all(dir_path = path, pattern = "*/**")
        Dir["#{dir_path}/#{pattern}/*.yml"].map {|p| Page.new p }
      end
      
      def find(permalink)
        pages[permalink] ||= find!(permalink)
      end
      
      private
      def find!(permalink)
        search_path = permalink.gsub(/\/$/, '').gsub(/\//, "/*")
        disk_path = Dir["#{path}/*#{search_path}/*.yml"]
        if disk_path.any?
          return new disk_path.first
        else
          raise NotFound, "page '#{permalink}' not found at '#{path}'"
        end
      end
    end
    
    attr_reader :disk_path
    
    def initialize(path)
      @disk_path = path
    end
    
    def slug
      permalink.gsub(/\/$/, '').split('/').pop
    end
    
    def name
      slug.gsub(/\W/, " ").gsub(/\d\./, '').gsub(/^\w/){$&.upcase}
    end
    
    def permalink
      web_path(directory) + '/'
    end
    
    def ctime; File.ctime(disk_path); end
    def mtime; File.mtime(disk_path); end
    
    def write_path
      "#{permalink}index.html"
    end
    
    def template
      Template.find(template_name)
    end
    
    # This method is used for the exporter to copy assets
    def assets
      Dir["#{directory}/**/*"].sort.select{|path| !File.directory?(path) && !File.basename(path).include?("yml") }.map do |file|
        file_to_hash(file)
      end
    end
    
    # "Floating pages" are pages that are not prefixed with a numeric eg: 1.about-us
    # These pages are not present in the `children` or other meta-content arrays
    def floating?
      !!(File.dirname(disk_path) =~ /\/[a-zA-z][\w-]+$/)
    end

    def parent
      id = permalink[/\/(.+\/)[^\/]*\/$/, 1]
      return nil if id.nil?
      
      parent = Page.find(id)
      return nil if parent == self
      
      parent
    rescue NotFound
      nil
    end
    
    def siblings
      self.class.all(File.dirname(disk_path[/(.+)\/[^\/]*$/, 1]), "*").delete_if{|p| p == self}
    end
    
    def children
      self.class.all(File.dirname(disk_path), "*").delete_if{|p| p.floating? }.sort_by{|p| p.disk_path }
    end
    
    def ancestors
      ancestors = []
      # Remove leading slash
      page_ref = permalink.gsub(/^\//, '')
      
      # Find pages up the permalink tree if possible
      while(page_ref) do
        page_ref = page_ref[/(.+\/)[^\/]*\/$/, 1]
        ancestors << self.class.find(page_ref) rescue NotFound
      end
      
      ancestors.compact.reverse
    end
    
    def ==(other)
      self.permalink == other.permalink
    end
    
    def render
      Tilt.new(template.path, :path => template.class.path).render(self, to_hash)
    end
    
    def content
      YAML::load(File.read(disk_path)) || {}
    rescue ArgumentError
      raise "Page '#{permalink}' has badly formatted content"
    end
    
    # This hash is available to all templates, it will map common properties, 
    # content file results, as well as any "magic" hashes for file 
    # system contents
    def to_hash
      hash = {
        :slug         => slug, 
        :permalink    => permalink, 
        :name         => name, 
        :children     => children,
        :siblings     => siblings,
        :parent       => parent, 
        :ancestors    => ancestors,
        :navigation   => Bonsai::Navigation.tree,
        :updated_at   => mtime,
        :created_at   => ctime
      }.merge(formatted_content).merge(disk_assets).merge(Bonsai.site)
      
      hash.stringify_keys
    end
    
    alias to_liquid to_hash
    
    private
    # This method ensures that multiline strings are run through markdown and smartypants
    def formatted_content
      formatted_content = content
      formatted_content.each do |k,v|
        if v.is_a?(String) and v =~ /\n/
          formatted_content[k] = to_markdown(v)
        end
      end
      
      formatted_content
    end
    
    def to_markdown(content)
      if defined? RDiscount
        RDiscount.new(content, :smart).to_html
      else
        Maruku.new(content).to_html
      end
    end
    
    # Creates "methods" for each sub-folder within the page's folder
    # that isn't itself, a child-page (a page object)
    def disk_assets
      assets = {}
      Dir["#{File.dirname(disk_path)}/**"].select{|p| File.directory?(p)}.reject {|p|
        Dir.entries(p).any?{|e| e.include? "yml"}
      }.each{|asset_path| assets.merge!(map_to_disk(asset_path)) }

      assets
    end
    
    def map_to_disk(path)
      name = File.basename(path)
      
      {
        name => Dir["#{path}/*"].map do |file|
          file_to_hash(file)
        end
      }
    end
    
    def directory
      disk_path.split("/")[0..-2].join("/")
    end
    
    def template_name
      File.basename(disk_path, '.*')
    end
    
    def web_path(path)
      path.gsub(self.class.path, '').gsub(/\/\d+\./, '/')
    end
    
    def file_to_hash(file)
      {
        :name       => File.basename(file, ".*").titleize,
        :path       => "#{web_path(File.dirname(file))}/#{File.basename(file)}",
        :disk_path  => File.expand_path(file)
      }.stringify_keys
    end
  end
end
