# This controller exposes the REST operations required to manage the Note
# resource.
class NotesController < NestedNodeResourceController

  before_filter :find_or_initialize_note, except: [:index, :new]
  before_filter :initialize_nodes_sidebar, only: [:edit, :new, :show]

  def new
    @note      = @node.notes.new
    @note.text = template_content if params[:template]
    # TODO use the textile-editor plugin
  end

  # Create a new Note for the associated Node.
  def create
    @note.author = current_user
    @note.category ||= Category.default

    if @note.save
      track_created(@note)
      redirect_to node_note_path(@node, @note), notice: 'Note created'
    else
      initialize_nodes_sidebar
      render "new"
    end
  end

  # Retrieve a Note given its :id
  def show
    @activities = @note.activities.latest
  end

  def edit
  end

  # Update the attributes of a Note
  def update
    if @note.update_attributes(note_params)
      track_updated(@note)
      redirect_to node_note_path(@node, @note), notice: 'Note updated.'
    else
      initialize_nodes_sidebar
      render 'edit'
    end
  end

  # Remove a Note from the back-end database.
  def destroy
    if @note.destroy
      track_destroyed(@note)
      redirect_to node_path(@node), notice: 'Note deleted'
    else
      redirect_to node_note_path(@node, @note), alert: 'Could not delete node'
    end
  end

  private

  # Once a valid @node is set by the previous filter we look for the Note we
  # are going to be working with based on the :id passed by the user.
  def find_or_initialize_note
    if params[:id]
      @note = Note.find(params[:id])
    elsif params[:note]
      @note = @node.notes.new(note_params)
    else
      @note = @node.notes.new
    end
  end

  def note_params
    params.require(:note).permit(:category_id, :node_id, :text)
  end
end
