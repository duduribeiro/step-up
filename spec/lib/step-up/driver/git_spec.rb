require 'spec_helper'

describe StepUp::Driver::Git do
  before do
    @driver = StepUp::Driver::Git.new
  end


  context 'fetching information' do
    it 'should get all commits from history log' do
      @driver.should respond_to :commit_history
      @driver.commit_history("f4cfcc2").should be == ["f4cfcc2c8b1f7edb1b7817b4e8a9063d21db089b", "2fb8a3281fb6777405aadcd699adb852b615a3e4", "d7b0fa26ca547b963569d7a82afd7d7ca11b71ae", "8b38f7c842496fd50b4e1b7ca5e883940b9cbf83", "f76c8d7bf64678963aeef84009be54f1819e3389", "8299243c7dac8f27c3572424a348a7f83ef0ce28", "570fe2e6e7f0b06140ae109e50a1e86628819493", "cdd4d5aa885b22136f4a08c1b35076f888f9536e", "72174c160b50ec73a8f67c8150e0dcd976857411", "b2da007b4fb35e0274858c14a83a836852d055a4", "4f0e7e0f6b3df2d49ed0029ed01998bf2102b28f"]
      @driver.commit_history("f4cfcc2", 3).should be == ["f4cfcc2c8b1f7edb1b7817b4e8a9063d21db089b", "2fb8a3281fb6777405aadcd699adb852b615a3e4", "d7b0fa26ca547b963569d7a82afd7d7ca11b71ae"]
    end
    it "should get all remotes" do
      @driver.fetched_remotes.should be == %w[origin]
    end
  end


  context 'fetching tags' do
    it "should get tags sorted" do
      tags = %w[note-v0.2.0-1 v0.1.0 v0.1.1 v0.1.2 v0.1.1.rc3]
      @driver.stubs(:all_tags).returns(tags)
      @driver.all_version_tags.should be == %w[v0.1.2 v0.1.1.rc3 v0.1.1 v0.1.0]
    end

    it "should return last tag visible" do
      @driver.last_version_tag("f4cfcc2").should be == "v0.0.1+"
      @driver.last_version_tag("570fe2e").should be == "v0.0.1"
      @driver.class.last_version("f4cfcc2").should be == "v0.0.1+"
      @driver.class.last_version("570fe2e").should be == "v0.0.1"
    end

    it "should get no tag visible" do
      @driver.last_version_tag("cdd4d5a").should be_nil
    end

    it "should get a blank tag" do
      @driver.mask.blank.should be == "v0.0.0"
      @driver.class.last_version("cdd4d5a").should be == "v0.0.0+"
    end
  end


  context "fetching notes" do
    context "from test_* sections" do
      before do
        @driver.stubs(:notes_sections).returns(%w[test_changes test_bugfixes test_features])
        @objects_with_notes = {"test_changes" => ["8299243c7dac8f27c3572424a348a7f83ef0ce28", "2fb8a3281fb6777405aadcd699adb852b615a3e4"], "test_bugfixes" => ["d7b0fa26ca547b963569d7a82afd7d7ca11b71ae"], "test_features" => []}
        @messages = {"test_changes" => ["removing files from gemspec\n  .gitignore\n  lastversion.gemspec\n", "loading default configuration yaml\n\nloading external configuration yaml\n"], "test_bugfixes" => ["sorting tags according to the mask parser\n"], "test_features" => []}
        @changelog_full = <<-MSG
  - removing files from gemspec (8299243c7dac8f27c3572424a348a7f83ef0ce28)
    - .gitignore
    - lastversion.gemspec
  - loading default configuration yaml (2fb8a3281fb6777405aadcd699adb852b615a3e4)
  - loading external configuration yaml

Test bugfixes:

  - sorting tags according to the mask parser (d7b0fa26ca547b963569d7a82afd7d7ca11b71ae)
MSG
        @changelog = @changelog_full.gsub(/\s\(\w+\)$/, '')
        @all_objects_with_notes = @driver.all_objects_with_notes("f4cfcc2")
      end
      it "should get all objects with notes" do
        @all_objects_with_notes.should be == @objects_with_notes
      end
      it "should get all notes messages" do
        @all_objects_with_notes.should respond_to(:messages)
        @all_objects_with_notes.messages.should be == @messages
      end
      it "should get changelog message" do
        @all_objects_with_notes.should respond_to(:to_changelog)
        @all_objects_with_notes.sections.should be == @driver.notes_sections
        @all_objects_with_notes.messages.should be == @messages
        @all_objects_with_notes.messages.to_changelog.should be == @changelog
        @all_objects_with_notes.to_changelog.should be == @changelog
        @all_objects_with_notes.messages.to_changelog(:mode => :with_objects).should be == @changelog_full
        @all_objects_with_notes.to_changelog(:mode => :with_objects).should be == @changelog_full
      end
      it "should get unversioned changelog message" do
        @all_objects_with_notes.should be == @objects_with_notes
        object = @objects_with_notes["test_changes"].shift
        @all_objects_with_notes.stubs(:kept_notes).returns([object])
        @all_objects_with_notes.should respond_to(:unversioned_only)
        @all_objects_with_notes.unversioned_only.should be == @objects_with_notes
      end
    end
  end


  context "increasing version" do
    before do
      @driver.stubs(:notes_sections).returns(%w[test_changes test_bugfixes test_features])
    end


    context "using 'remove' as after_versioned:strategy" do
      before do
        @driver.stubs(:notes_after_versioned).returns({"strategy" => "remove", "section" => "test_versioning", "changelog_message" => "available on {version}"})
        @steps = <<-STEPS
        git fetch

        git tag -a -m "  - removing files from gemspec
            - .gitignore
            - lastversion.gemspec
          - loading default configuration yaml
          - loading external configuration yaml
        
        Test bugfixes:
        
          - sorting tags according to the mask parser
        " v0.1.0

        git push --tags

        git notes --ref=test_changes remove 8299243c7dac8f27c3572424a348a7f83ef0ce28

        git notes --ref=test_changes remove 2fb8a3281fb6777405aadcd699adb852b615a3e4

        git push origin refs/notes/test_changes

        git notes --ref=test_bugfixes remove d7b0fa26ca547b963569d7a82afd7d7ca11b71ae

        git push origin refs/notes/test_bugfixes
        STEPS
        @steps = @steps.chomp.split(/\n\n/).collect{ |step| step.gsub(/^\s{8}/, '') }
      end
      it "should return steps" do
        @driver.should respond_to :increase_version_tag
        @driver.increase_version_tag("minor", "f4cfcc2").should be == @steps
      end
    end


    context "using 'keep' as after_versioned:strategy" do
      before do
        @driver.stubs(:notes_after_versioned).returns({"strategy" => "keep", "section" => "test_versioning", "changelog_message" => "available on {version}"})
        @steps = <<-STEPS
        git fetch

        git tag -a -m "  - removing files from gemspec
            - .gitignore
            - lastversion.gemspec
          - loading default configuration yaml
          - loading external configuration yaml
        
        Test bugfixes:
        
          - sorting tags according to the mask parser
        " v0.1.0

        git push --tags

        git notes --ref=test_versioning add -m "available on v0.1.0" 8299243c7dac8f27c3572424a348a7f83ef0ce28

        git notes --ref=test_versioning add -m "available on v0.1.0" 2fb8a3281fb6777405aadcd699adb852b615a3e4

        git notes --ref=test_versioning add -m "available on v0.1.0" d7b0fa26ca547b963569d7a82afd7d7ca11b71ae

        git push origin refs/notes/test_versioning
        STEPS
        @steps = @steps.chomp.split(/\n\n/).collect{ |step| step.gsub(/^\s{8}/, '') }
      end
      it "should return steps" do
        @driver.should respond_to :increase_version_tag
        @driver.increase_version_tag("minor", "f4cfcc2").should be == @steps
      end
    end
  end


  context "checking helper methods" do
    it "should load default notes' sections" do
      @driver.send(:notes_sections).should be == StepUp::CONFIG["notes"]["sections"]
    end
  end
end
