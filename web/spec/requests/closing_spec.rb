require "rails_helper"

RSpec.describe "Closing joining", type: :request do
  around { |example| with_passphrase { example.run } }

  let(:created) { create_game(power: "england") }
  let(:game) { created.game }
  let(:id) { game.public_id }
  let(:path) { "/games/#{id}/host/close" }

  def stranger_page?(response)
    response.status == 404 && response.body.include?("We can't find that page.")
  end

  describe "the confirmation page (AC-6.1)" do
    it "warns that closing cannot be undone, offers a danger button and a way back" do
      created.session.get path

      page = Nokogiri::HTML5(created.session.response.body)
      expect(created.session.response).to have_http_status(:ok)
      expect(page.css("title").text).to eq("Close joining")
      expect(page.at_css("h1").text).to eq("Close joining")
      expect(page.text).to include("Closing cannot be undone.")
      form = page.at_css("form[action='#{path}']")
      expect(form["method"]).to eq("post")
      expect(form.at_css("button.button.button--danger").text).to eq("Close joining")
      back = page.at_css("a.button.button--secondary")
      expect(back.text).to eq("Back")
      expect(back["href"]).to eq("/games/#{id}/host")
      expect(game.reload.joining_closed_at).to be_nil
    end
  end

  describe "closing (AC-6.2)" do
    it "closes joining and returns to a host page with no code" do
      created.session.post path

      expect(created.session.response.location).to eq("http://www.example.com/games/#{id}/host")
      expect(game.reload.joining_closed_at).to be_present

      created.session.follow_redirect!
      page = Nokogiri::HTML5(created.session.response.body)
      expect(page.text).to include("Joining is closed.")
      expect(page.at_css(".qr-card")).to be_nil
      expect(page.at_css(".join-code")).to be_nil
    end
  end

  describe "a phone without the host cookie (AC-6.4)" do
    it "gets the stranger page for the page and the post, and joining stays open" do
      phone = seat_only_session(created)

      phone.get path
      expect(stranger_page?(phone.response)).to be(true)
      phone.post path
      expect(stranger_page?(phone.response)).to be(true)

      expect(game.reload.joining_closed_at).to be_nil
    end
  end

  describe "closing twice (AC-6.5)" do
    it "changes nothing the second time" do
      created.session.post path
      closed_at = game.reload.joining_closed_at
      updated_at = game.updated_at

      created.session.post path

      expect(created.session.response.location).to eq("http://www.example.com/games/#{id}/host")
      expect(game.reload.joining_closed_at).to eq(closed_at)
      expect(game.updated_at).to eq(updated_at)
    end
  end
end
