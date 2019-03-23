require "../spec_helper"

class TestMiddleware < CrystalTask::Middleware::Entry
  def call(job : CrystalTask::Job, &block : -> Bool) : Bool
    true
  end
end

class MoreTestMiddleware < CrystalTask::Middleware::Entry
  def call(job : CrystalTask::Job, &block : -> Bool) : Bool
    true
  end
end

class MoreMoreTestMiddleware < CrystalTask::Middleware::Entry
  def call(job : CrystalTask::Job, &block : -> Bool) : Bool
    true
  end
end

describe CrystalTask::Middleware::Chain do
  describe "#add" do
    it "should add the middleware" do
      chain = CrystalTask::Middleware::Chain(CrystalTask::Middleware::Entry).new
      chain.add(TestMiddleware.new)

      chain.middleware[0].should be_a(TestMiddleware)
    end

    it "should not add the same middleware twice" do
      chain = CrystalTask::Middleware::Chain(CrystalTask::Middleware::Entry).new
      chain.add(TestMiddleware.new)
      chain.add(TestMiddleware.new)

      chain.middleware.size.should eq 1
    end
  end

  describe "#delete" do
    it "should delete middleware" do
      chain = CrystalTask::Middleware::Chain(CrystalTask::Middleware::Entry).new
      chain.add(TestMiddleware.new)
      chain.delete(TestMiddleware.new)

      chain.middleware.size.should eq 0
    end
  end

  describe "#insert_before" do
    it "should insert before" do
      chain = CrystalTask::Middleware::Chain(CrystalTask::Middleware::Entry).new
      chain.add(TestMiddleware.new)
      chain.add(MoreTestMiddleware.new)
      chain.insert_before(MoreTestMiddleware, MoreMoreTestMiddleware.new)

      chain.middleware.size.should eq 3
      chain.middleware[1].class.should eq MoreMoreTestMiddleware
    end

    it "should raise exception if the old class is not found" do
      chain = CrystalTask::Middleware::Chain(CrystalTask::Middleware::Entry).new
      chain.add(TestMiddleware.new)

      expect_raises(CrystalTask::Middleware::NotFoundException) do
        chain.insert_before(MoreTestMiddleware, MoreMoreTestMiddleware.new)
      end
    end
  end

  describe "#insert_after" do
    it "should insert before" do
      chain = CrystalTask::Middleware::Chain(CrystalTask::Middleware::Entry).new
      chain.add(TestMiddleware.new)
      chain.add(MoreTestMiddleware.new)
      chain.insert_after(TestMiddleware, MoreMoreTestMiddleware.new)

      chain.middleware.size.should eq 3
      chain.middleware[1].class.should eq MoreMoreTestMiddleware
    end

    it "should raise exception if the old class is not found" do
      chain = CrystalTask::Middleware::Chain(CrystalTask::Middleware::Entry).new
      chain.add(TestMiddleware.new)

      expect_raises(CrystalTask::Middleware::NotFoundException) do
        chain.insert_after(MoreTestMiddleware, MoreMoreTestMiddleware.new)
      end
    end
  end
end
