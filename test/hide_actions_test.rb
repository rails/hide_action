require 'test_helper'

# Provide some controller to run the tests on.
module Submodule
  class ContainedEmptyController < ActionController::Base
  end

  class ContainedNonEmptyController < ActionController::Base
    def public_action
      render :nothing => true
    end

    hide_action :hidden_action
    def hidden_action
      raise "Noooo!"
    end

    def another_hidden_action
    end
    hide_action :another_hidden_action
  end

  class SubclassedController < ContainedNonEmptyController
    hide_action :public_action # Hiding it here should not affect the superclass.
  end
end

class EmptyController < ActionController::Base
end

class NonEmptyController < ActionController::Base
  def public_action
    render :nothing => true
  end

  hide_action :hidden_action
  def hidden_action
  end
end

class MethodMissingController < ActionController::Base
  hide_action :shouldnt_be_called
  def shouldnt_be_called
    raise "NO WAY!"
  end

protected

  def method_missing(selector)
    render :text => selector.to_s
  end
end

class DefaultUrlOptionsController < ActionController::Base
  def from_view
    render :inline => "<%= #{params[:route]} %>"
  end

  def default_url_options(options = nil)
    { :host => 'www.override.com', :action => 'new', :locale => 'en' }
  end
end

class ControllerInstanceTests < Test::Unit::TestCase
  def setup
    @empty = EmptyController.new
    @contained = Submodule::ContainedEmptyController.new
    @empty_controllers = [@empty, @contained, Submodule::SubclassedController.new]

    @non_empty_controllers = [NonEmptyController.new,
                              Submodule::ContainedNonEmptyController.new]
  end

  def test_action_methods
    @empty_controllers.each do |c|
      assert_equal Set.new, c.class.__send__(:action_methods), "#{c.controller_path} should be empty!"
    end

    @non_empty_controllers.each do |c|
      assert_equal Set.new(%w(public_action)), c.class.__send__(:action_methods), "#{c.controller_path} should not be empty!"
    end
  end
end

class PerformActionTest < ActionController::TestCase
  def use_controller(controller_class)
    @controller = controller_class.new

    # enable a logger so that (e.g.) the benchmarking stuff runs, so we can get
    # a more accurate simulation of what happens in "real life".
    @controller.logger = Logger.new(nil)

    @request     = ActionController::TestRequest.new
    @response    = ActionController::TestResponse.new
    @request.host = "www.nextangle.com"

    rescue_action_in_public!
  end

  def test_get_on_priv_should_show_selector
    use_controller MethodMissingController
    get :shouldnt_be_called
    assert_response :success
    assert_equal 'shouldnt_be_called', @response.body
  end

  def test_get_on_hidden_should_fail
    use_controller NonEmptyController
    assert_raise(ActionController::UnknownAction) { get :hidden_action }
    assert_raise(ActionController::UnknownAction) { get :another_hidden_action }
  end
end