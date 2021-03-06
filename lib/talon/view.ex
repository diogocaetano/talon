defmodule Talon.View do
  @moduledoc """
  View related API functions

  TBD
  """

  alias Talon.Schema

  defmacro __using__(_) do
    quote do
      import Phoenix.HTML.Tag
      import Phoenix.HTML.Link

      @spec concern(Plug.Conn.t) :: atom
      def concern(conn) do
        conn.assigns.talon.concern
      end

      @doc """
      Helper to return the current `talon_resource` module.

      Extract the `talon_resource` module from the conn.assigns
      """
      @spec talon_resource(Plug.Conn.t) :: atom
      def talon_resource(conn) do
        conn.assigns.talon.talon_resource
      end

      # TODO: Consider renaming page_paths/presource_paths as page/resource_links. (DJS)
      # TODO: return the resource type (:page/:backed) as well. With that, we could offer a single resource_links.
      #       Could return the resource module as well for easy handling of additional callbacks, if needed. (DJS)

      def resource_paths(conn) do  # TODO: don't repeat logic done in Concern, see page_paths (DJS)
        concern = conn.assigns.talon.concern
        concern.resources()
        |> Enum.map(fn tr ->
          {tr.display_name_plural(), concern.resource_path(tr.schema, :index)}
        end)
      end

      def resource_path(conn, resource, action, opts \\ []) do
        Talon.Concern.resource_path conn, resource, action, opts # TODO: why use Talon.Concern here? (DJS)
      end

      def page_paths(conn) do
        concern(conn).page_paths(conn)
      end

      def search_path(conn) do
        resource_path(conn, :search, [""])
      end

      def nav_action_links(conn) do
        Talon.Concern.nav_action_links(conn) # TODO: why use Talon.Concern here? (DJS)
      end

      def index_card_title(conn) do
        talon_resource(conn).index_card_title()
      end

      defoverridable([
        talon_resource: 1, resource_paths: 1, nav_action_links: 1,
        resource_path: 4
      ])

    end
  end

  def view_module(conn, view) do
    Module.concat [
      Talon.Concern.concern(conn),
      Talon.View.theme_module(conn),
      Talon.Concern.web_namespace(conn),
      view
    ]
  end

  @doc """
  Return the humanized field name the field value.

  Reflect on the field type. Return the association display name or
  the field value for non associations.

  For associations:
  * Use the Schema's `display_name/1` if defined
  * Use the schema's `:name` field if it exists
  * Otherwise, return "No Display Name"

  TODO: Need to use overridable decorators to resolve value types
  """
  @spec get_resource_field(Module.t, Struct.t, atom) :: {String.t, any}
  def get_resource_field(concern, resource, name) do
    schema = resource.__struct__
    type = schema.__schema__(:type, name)
    schema
    |> Schema.associations()
    |> Keyword.get(name)
    |> get_resource_field(concern, type, resource, schema, name)
  end

  defp get_resource_field(nil, _concern, _, resource, _, name) do
    {Talon.Utils.titleize(to_string name), format_data(Map.get(resource, name))}
  end

  defp get_resource_field(%{field: field, related: _related}, concern, _, resource, _, _name) do
    assoc_resource = Map.get(resource, field)
    value =
      if association_loaded? assoc_resource do
        concern.display_name(assoc_resource)
      else
        concern.messages_backend().not_loaded()
      end
    {Talon.Utils.titleize(to_string field), format_data(value)}
  end

  defp get_resource_field(_, _, _, _resource, _, name) do
    {Talon.Utils.titleize(to_string name), "unknown type"}
  end

  @doc """
  Helper to return the current `talon_resource` module.

  Extract the `talon_resource` module from the conn.assigns
  """
  @spec talon_resource(Plug.Conn.t) :: atom
  def talon_resource(conn) do
    conn.assigns.talon[:talon_resource]
  end

  @doc """
  Extract the params_key from the conn
  """
  @spec params_key(Plug.Conn.t) :: String.t
  def params_key(conn) do
    talon_resource(conn).params_key()
  end

  @doc """
  Extract the repo form the conn
  """
  @spec repo(Plug.Conn.t) :: Struct.t
  def repo(conn) do
    conn.assigns.talon.repo
  end

  @doc """
  Get the current theme module.

  ## Examples

      iex> Talon.View.theme_module(%{assigns: %{talon: %{theme: "admin-lte"}}})
      AdminLte
  """
  @spec theme_module(Plug.Conn.t) :: atom
  def theme_module(conn) do
    conn.assigns.talon.theme
    |> Inflex.camelize
    |> Module.concat(nil)
  end

  @doc """
  Check if the value of an association is loaded
  """
  @spec association_loaded?(any) :: boolean
  def association_loaded?(%Ecto.Association.NotLoaded{}), do: false
  def association_loaded?(%{}), do: true
  def association_loaded?(_), do: false

  # TODO: this is only temporary. Need to use orverridable decorator concept here
  def format_data(data) when is_binary(data), do: data
  def format_data(data) when is_number(data), do: data
  def format_data(data), do: inspect(data)

end
