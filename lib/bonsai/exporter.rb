require 'fileutils'
require 'sass'
require 'yui/compressor'

module Bonsai
  class Exporter
    class << self
      attr_accessor :path
      def path; @path || "output"; end
      
      def process!
        setup
        copy_public
        copy_assets
        cleanup
      end
      
      def publish!
        teardown
        setup
        copy_assets
        copy_public
        compress_assets
        write_index
        write_pages
        write_sitemap
        write_readme
        cleanup
      end

      def publish_without_compression!
        teardown
        setup
        copy_assets
        # jms mod below
        copy_public_without_css_gen
        # compress_assets
        write_index
        write_pages
        write_sitemap
        write_readme
        cleanup
      end

      def publish_flat_without_compression!
        teardown
        setup
        copy_assets
        # jms mod below
        copy_public_without_css_gen
        # compress_assets
        write_index
        write_pages_flat
        write_sitemap
        write_readme
        cleanup
      end
      
      def copy_public
        generate_css
        
        Bonsai.log "Copying public files"
        # Using system call because fileutils is inadequate
        system("cp -fR '#{Bonsai.root_dir}/public/.' '#{path}/.'")
      end
      
      # jms mod below
      def copy_public_without_css_gen
        # generate_css
        
        Bonsai.log "Copying public files"
        # Using system call because fileutils is inadequate
        system("cp -fR '#{Bonsai.root_dir}/public/.' '#{path}/.'")
      end
      
      def compress_assets
        Bonsai.log "Compressing javascript and stylesheets"
        compress_asset_path("#{path}/**/*.js", YUI::JavaScriptCompressor.new)
        compress_asset_path("#{path}/**/*.css", YUI::CssCompressor.new)
      end
      
      protected 
      def compress_asset_path(paths, compressor)
        Dir[paths].each do |path|
          uncompressed = File.read(path)
          File.open(path, "w") do |buffer|
            buffer << compressor.compress(uncompressed)
          end
        end
      end

      def teardown
        FileUtils.rm_rf path
      end

      def setup
        FileUtils.mkdir_p path
      end
      
      def cleanup
        remove_less_sass
      end
      
      def write_index
        Bonsai.log "Writing index"
        File.open("#{path}/index.html", "w") {|file| file.write(Page.find("index").render)}
      end
      
      def write_pages
        Bonsai.log "Writing pages"
        Page.all.each do |page|
          Bonsai.log "\t Writing page - #{page.permalink}"
          FileUtils.mkdir_p("#{path}#{page.permalink}")
          File.open("#{path}#{page.write_path}", "w"){|file| file.write(page.render) }
        end
      end
      
      # jms mod
      def write_pages_flat
        Bonsai.log "Writing pages"
        Page.all.each do |page|
          Bonsai.log "\t Writing page - #{page.permalink}"
          # FileUtils.mkdir_p("#{path}#{page.permalink}")
          File.open("#{path}#{page.permalink}.html", "w"){|file| file.write(page.render) }
        end
      end
      
      def write_sitemap
        Bonsai.log "Writing sitemap"
        File.open("#{path}/sitemap.xml", "w") {|file| file.write(Bonsai::Sitemap.generate) }
      end
      
      def write_readme
        Bonsai.log "Writing ABOUT-THIS-SITE"
        
        readme = <<-README
          This site was built using Bonsai (http://tinytree.info)
                
          To make changes to the site using Bonsai you will require the original source files.
          Please contact the author of your site for details.
          
          It may also be a good idea to ensure that you've got Bonsai version #{Bonsai::VERSION} or higher.
          If you experience any unexplainable issues try uninstalling all versions of Bonsai (`gem uninstall bonsai`) and install version #{Bonsai::VERSION} (`gem install bonsai -v #{Bonsai::VERSION}`)
        README
        
        File.open("#{path}/ABOUT-THIS-SITE.txt", "w") {|file| file.write(readme) }
      end
      
      def copy_assets
        Bonsai.log "Copying page assets"
        Page.all.each do |page|
          page.assets.each do |asset|      
            # Create the path to the asset by the export path of the page + File.dirname(asset permalink)
            FileUtils.mkdir_p "#{path}#{File.dirname(asset['path'])}"
            
            # Copy the the asset from its disk path to File.dirname(asset permalink)
            FileUtils.cp asset['disk_path'], "#{path}#{asset['path']}"
          end
        end
      end
      
      def generate_css
        Dir["#{Bonsai.root_dir}/public/**/*.{less,sass,scss}"].each do |cssfile|
          css = Tilt.new(cssfile).render
          path = "#{File.dirname(cssfile)}/#{File.basename(cssfile, ".*")}.css"
          
          File.open(path, "w") {|file| file.write(css) }
        end
      rescue Sass::SyntaxError => exception
        Bonsai.log "CSS Syntax error\n\n#{exception.message}"
      end
      
      def remove_less_sass
        Dir["#{path}/**/*.{less,sass}"].each{|f| FileUtils.rm(f) }
      end
    end
  end
end