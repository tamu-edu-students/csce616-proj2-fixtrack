require "rails_helper"

RSpec.describe EquipmentController, type: :controller do
  render_views

  let(:attributes) { { name: "Oscilloscope", asset_identifier: "LAB-001", location: "Lab A", status: "Available" } }
  let(:item) { Equipment.create!(attributes) }

  # Issue #4 will supply these Devise methods and the User#manager? role.
  # Until then, isolate the equipment controller against that explicit contract.
  before do
    controller.define_singleton_method(:authenticate_user!) { }
    controller.define_singleton_method(:current_user) { }
    controller.class.helper_method :current_user
    allow(controller).to receive(:current_user).and_return(double(manager?: true))
  end

  it "creates and reloads valid equipment" do
    expect { post :create, params: { equipment: attributes } }.to change(Equipment, :count).by(1)
    expect(Equipment.last.reload.name).to eq("Oscilloscope")
    expect(response).to redirect_to(equipment_path(Equipment.last))
  end

  it "shows field errors and preserves input after an invalid create" do
    expect { post :create, params: { equipment: attributes.merge(name: "") } }.not_to change(Equipment, :count)
    expect(response).to have_http_status(:unprocessable_content)
    expect(response.body).to include("name_errors", "LAB-001")
  end

  it "updates an existing record" do
    patch :update, params: { id: item.id, equipment: { location: "Lab B" } }
    expect(item.reload.location).to eq("Lab B")
  end

  it "does not persist invalid updates" do
    patch :update, params: { id: item.id, equipment: { name: "Changed", location: "" } }
    expect(response).to have_http_status(:unprocessable_content)
    expect(item.reload.name).to eq("Oscilloscope")
  end

  it "shows an empty state" do
    get :index
    expect(response.body).to include("No equipment has been registered.")
  end

  it "renders creation and edit forms" do
    get :new
    expect(response.body).to include("Create equipment")
    get :edit, params: { id: item.id }
    expect(response.body).to include("Save changes")
  end

  it "does not delete on the confirmation GET" do
    id = item.id
    expect { get :confirm_destroy, params: { id: id } }.not_to change(Equipment, :count)
    expect(response.body).to include("Confirm removal", "Cancel")
  end

  it "removes confirmed equipment" do
    id = item.id
    expect { delete :destroy, params: { id: id } }.to change(Equipment, :count).by(-1)
    expect(response).to redirect_to(equipment_index_path)
  end

  it "reports a blocked deletion without claiming success" do
    allow(Equipment).to receive(:find).and_return(item)
    item.errors.add(:base, "Equipment with maintenance history cannot be removed.")
    allow(item).to receive(:destroy).and_return(false)
    delete :destroy, params: { id: item.id }
    expect(response).to redirect_to(equipment_path(item))
    expect(flash[:alert]).to include("maintenance history")
    expect(Equipment.exists?(item.id)).to be(true)
  end

  it "returns a controlled response for missing equipment" do
    get :show, params: { id: 0 }
    expect(response).to have_http_status(:not_found)
  end

  context "as a technician" do
    before { allow(controller).to receive(:current_user).and_return(double(manager?: false)) }

    it "allows listing and viewing equipment without modification links" do
      item
      get :index
      expect(response).to have_http_status(:ok)
      expect(response.body).not_to include("Add equipment")
      get :show, params: { id: item.id }
      expect(response.body).to include("Oscilloscope", "Available")
      expect(response.body).not_to include("Edit equipment")
      expect(response.body).not_to include("Remove equipment")
    end

    [ :new, :edit, :confirm_destroy ].each do |action|
      it "forbids the #{action} page" do
        get action, params: { id: item.id }
        expect(response).to have_http_status(:forbidden)
      end
    end

    [ [ :post, :create ], [ :patch, :update ], [ :delete, :destroy ] ].each do |verb, action|
      it "forbids direct #{action} without changing data" do
        item
        before_data = Equipment.order(:id).map(&:attributes)
        public_send(verb, action, params: { id: item.id, equipment: attributes.merge(name: "Unauthorized") })
        expect(response).to have_http_status(:forbidden)
        expect(Equipment.order(:id).map(&:attributes)).to eq(before_data)
      end
    end
  end

  it "requires authentication before looking up equipment" do
    allow(controller).to receive(:authenticate_user!) { controller.head :unauthorized }
    get :show, params: { id: item.id }
    expect(response).to have_http_status(:unauthorized)
  end

    context "equipment record details" do
    let(:record_details) do
      {
        manufacture_date: "2020-05-15",
        specifications: "Supply voltage: 120 V"
      }
    end

    it "saves record details when a manager creates equipment" do
      post :create, params: {
        equipment: attributes.merge(record_details)
      }

      expect(response).to have_http_status(:redirect)

      saved = Equipment.find_by!(asset_identifier: "LAB-001")
      expect(saved.manufacture_date).to eq(Date.new(2020, 5, 15))
      expect(saved.specifications).to eq("Supply voltage: 120 V")
    end

    it "saves record details when a manager updates equipment" do
      patch :update, params: {
        id: item.id,
        equipment: record_details
      }

      expect(response).to have_http_status(:redirect)
      expect(item.reload.manufacture_date).to eq(Date.new(2020, 5, 15))
      expect(item.specifications).to eq("Supply voltage: 120 V")
    end

    it "allows technicians to read record details without edit controls" do
      item.update!(record_details)
      allow(controller).to receive(:current_user)
        .and_return(double(manager?: false))

      get :show, params: { id: item.id }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("2020-05-15")
      expect(response.body).to include("Supply voltage: 120 V")
      expect(response.body).not_to include("Edit equipment")
      expect(response.body).not_to include("Remove equipment")
    end

    it "prevents technicians from changing record details" do
      item.update!(record_details)
      allow(controller).to receive(:current_user)
        .and_return(double(manager?: false))

      patch :update, params: {
        id: item.id,
        equipment: {
          manufacture_date: "2025-01-01",
          specifications: "Unauthorized change"
        }
      }

      expect(response).to have_http_status(:forbidden)
      expect(item.reload.manufacture_date).to eq(Date.new(2020, 5, 15))
      expect(item.specifications).to eq("Supply voltage: 120 V")
    end

    it "displays placeholders when optional record details are absent" do
      get :show, params: { id: item.id }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Manufacture date", "Specifications")
      expect(response.body.scan("Not provided.").length).to eq(2)
    end
  end
end
