# frozen_string_literal: true

# Cloud Foundry TomEE Buildpack
# Copyright 2013-2019 the original author or authors.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

require 'java_buildpack/component/modular_component'
require 'java_buildpack/container'
require 'java_buildpack/container/tomcat/tomcat_insight_support'
require 'java_buildpack/container/tomee/tomee_instance'
require 'java_buildpack/container/tomee/tomee_resource_configuration'
require 'java_buildpack/container/tomcat/tomcat_external_configuration'
require 'java_buildpack/container/tomcat/tomcat_lifecycle_support'
require 'java_buildpack/container/tomcat/tomcat_logging_support'
require 'java_buildpack/container/tomcat/tomcat_access_logging_support'
require 'java_buildpack/container/tomcat/tomcat_redis_store'
require 'java_buildpack/container/tomcat/tomcat_setenv'
require 'java_buildpack/util/java_main_utils'

module JavaBuildpack
  module Container

    # Encapsulates the detect, compile, and release functionality for Tomee applications.
    class Tomee < JavaBuildpack::Component::ModularComponent

      protected

      # (see JavaBuildpack::Component::ModularComponent#command)
      def command
        @droplet.environment_variables.add_environment_variable 'JAVA_OPTS', '$JAVA_OPTS'
        @droplet.java_opts.add_system_property 'http.port', '$PORT'

        [
          @droplet.environment_variables.as_env_vars,
          @droplet.java_home.as_env_var,
          'exec',
          "$PWD/#{(@droplet.sandbox + 'bin/catalina.sh').relative_path_from(@droplet.root)}",
          'run'
        ].flatten.compact.join(' ')
      end

      # (see JavaBuildpack::Component::ModularComponent#sub_components)
      def sub_components(context)
        components = [
          TomeeInstance.new(sub_configuration_context(context, 'tomee')),
          TomeeResourceConfiguration.new(sub_configuration_context(context, 'resource_configuration')),
          TomcatLifecycleSupport.new(sub_configuration_context(context, 'lifecycle_support')),
          TomcatInsightSupport.new(context),
          TomcatLoggingSupport.new(sub_configuration_context(context, 'logging_support')),
          TomcatAccessLoggingSupport.new(sub_configuration_context(context, 'access_logging_support')),
          TomcatRedisStore.new(sub_configuration_context(context, 'redis_store')),
          TomcatSetenv.new(context)
        ]

        tomee_configuration = @configuration['tomee']
        components << TomcatExternalConfiguration.new(sub_configuration_context(context, 'external_configuration')) if
          tomee_configuration['external_configuration_enabled']

        components
      end

      # (see JavaBuildpack::Component::ModularComponent#supports?)
      def supports?
        (web_inf? && !JavaBuildpack::Util::JavaMainUtils.main_class(@application)) || ear?
      end

      private

      def ear?
        (@application.root + 'META-INF/application.xml').exist?
      end

      def web_inf?
        (@application.root + 'WEB-INF').exist?
      end

    end

  end
end
