require File.expand_path('../../../test_helper', __FILE__)

class RestApiCartridgeTypeTest < ActiveSupport::TestCase

  def setup
    with_configured_user
  end

  def log_types(types)
    types.each do |t|
      Rails.logger.debug <<-TYPE.strip_heredoc
        Type #{t.display_name} (#{t.id})
          description: #{t.description}
          tags:        #{t.tags.inspect}
          version:     #{t.version}
          cartridges:  #{t.respond_to?(:cartridges) ? t.cartridges.join(', ') : 'n/a'}
          priority:    #{t.priority}
        #{log_extra(t)}
      TYPE
    end
  end
  def log_extra(type)
    if type.respond_to?(:requires)
      "  requires:    #{type.requires.inspect}\n"
    end
  end

  test 'should load embedded cartridge types from server' do
    types = CartridgeType.embedded
    assert types.length > 0
    types.sort!

    log_types(types)

    assert type = types.find{ |t| t.name.starts_with?('phpmyadmin-') }
    assert type.requires.find{ |r| r.starts_with?('mysql-') }, type.requires.inspect
    assert type.tags.include? :administration
    assert_not_equal type.name, type.display_name

    assert (required = types.select{ |t| t.requires.present? }).length > 1
    assert types.all?{ |t| t.tags.present? }
    assert types.all?{ |t| t.tags.present? }
    assert types.all?{ |t| (t.tags & t.categories).sort.uniq == t.categories.sort.uniq }
  end

  test 'should load standalone cartridge types' do
    types = CartridgeType.standalone
    assert types.length > 0
    types.sort!

    log_types(types)

    assert types[0].name.starts_with?('jbosseap-')
  end

  test 'should load metadata from broker' do
    assert type = CartridgeType.find('zend-5.6')
    assert type.tags.include?(:web_framework), type.tags.inspect
    assert_not_equal type.name, type.display_name
  end

  test 'should load application types' do
    types = ApplicationType.all
    assert types.length > 0

    types.sort!
    log_types(types)

    assert types[0].id.starts_with?('cart!jbosseap'), types[0].id

    type = types.find(&:template?)
    omit("No templates defined on this server") if type.nil?

    template = type.template
    assert template.name
    assert template.description
    assert template.version
    assert template.website
    assert template.git_url
    assert template.git_project_url
    assert_equal type.id, "template!#{template.name}"
    assert template.git_project_url
    assert_same template.tags, template.tags
  end

  test 'sort cartridges' do
    array = ['diy-0.1','mongodb-2.2'].map{ |s| Cartridge.new(:name => s) }
    assert_equal array.map(&:name), array.sort.map(&:name)
  end

  test 'cartridges are sorted properly' do
    ruby18 = CartridgeType.find 'ruby-1.8'
    ruby = CartridgeType.find 'ruby-1.9'
    php = CartridgeType.find 'php-5.3'
    mongo = CartridgeType.find 'mongodb-2.2'
    cron = CartridgeType.find 'cron-1.4'
    jenkins = CartridgeType.find 'jenkins-client-1.4'

    assert ruby18 > ruby
    assert ruby < ruby18

    assert cron > ruby
    assert ruby < cron

    assert mongo < cron
    assert cron > mongo

    assert ruby < mongo
    assert mongo > ruby

    assert php < ruby
    assert ruby > php

    assert php < jenkins
    assert ruby < jenkins
  end

  # Currently /application_templates/<string>.json can return an array
  # if the value is not a properly formatted ID.  This is questionable,
  # and this test is only to protect us in the case that we have code
  # depending on that behavior.  If this behavior is moved to a new
  # route then we can remove this.
  test 'application template names returned by server' do
    assert template = ApplicationTemplate.first(:from => :wordpress)
    assert_equal 'WordPress', template.display_name
  end
end
