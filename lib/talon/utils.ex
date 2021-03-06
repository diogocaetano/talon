defmodule Talon.Utils do
  @moduledoc """
  A collection of utility functions.
  """
  use Talon.Config
  alias Talon.Messages

  require Logger

  # @module Application.get_env(:talon, :module)

  # if @module do
  #   @namespace Application.get_env(:talon, :web_namespace)
  #   @endpoint Module.concat([@module, @namespace, "Endpoint"])
  #   @router Module.concat([@module, @namespace, "Router", "Helpers"])

  #   @doc false
  #   def endpoint, do: @endpoint
  #   @doc false
  #   def router, do: @router
  # else
  #   # run time version of endpoint and router
  #   Logger.warn """
  #   Talon requires recompiling after adding :talon configuration in your config/config.exs file.
  #   After running 'mix talon.install' and updating your config.exs file, please
  #   run 'touch deps/talon/mix.exs && mix deps.compile talon'.
  #   """
  #   @doc false
  #   def endpoint, do: Module.concat([Application.get_env(:talon, :module), "Endpoint"])
  #   @doc false
  #   def router, do: Module.concat([Application.get_env(:talon, :module), "Router", "Helpers"])
  # end

  # TODO: This needs to be done differently. In needs to be scoped to the
  #       applicable talon concern

  def router do
    module = Application.get_env(:talon, :module)
    namespace =  Application.get_env(:talon, :web_namespace)
    Module.concat([module, namespace, "Router"])
  end

  def router_helpers do
    Module.concat router(), "Helpers"
  end

  def endpoint do
    module = Application.get_env(:talon, :module)
    namespace =  Application.get_env(:talon, :web_namespace)
    Module.concat([module, namespace, "Endpoint"])
  end

  @doc "Pads with zero"
  def zero_pad(val, count) do
    num = Integer.to_string(val)
    pad_length = max(count - byte_size(num), 0)
    :binary.copy("0", pad_length) <> num
  end

  @doc false
  def to_atom(string) when is_binary(string), do: String.to_atom(string)
  def to_atom(atom) when is_atom(atom), do: atom

  @doc false
  def base_name(item) when is_atom(item) do
    Atom.to_string(item)
    |> base_name
  end
  def base_name(item) do
    item
    |> String.split(".")
    |> List.last
  end

  @doc false
  def resource_name(item) do
    item |> base_name |> Inflex.underscore |> String.to_atom
  end


  @doc false
  def module_name(module) do
    module |> base_name |> Inflex.underscore
  end

  @doc """
  Convert a field name to its human readable form.

  Converts items like field names to a form suitable for display
  labels and menu items. By default, converts _ to space and
  capitalizes each word.

  The conversion can be customized by passing a from regex and to
  regex as the 2nd and 3rd arguments.

  ## Examples:

      iex> Talon.Utils.humanize :first_name
      "First Name"

      iex> Talon.Utils.humanize "last-name", ~r/[-]/
      "Last Name"

  """
  def humanize(item, from \\ ~r/[_ ]/, to \\ " ")
  def humanize(atom, from, to) when is_atom(atom) do
    Atom.to_string(atom)
    |> humanize(from, to)
  end
  def humanize(string, from, to) when is_binary(string) do
    String.split(string, from)
    |> Enum.map(&(String.capitalize(&1)))
    |> Enum.join(to)
  end

  @doc """
  Converts camel case items to human readable form.

  ## Examples

      iex> Talon.Utils.titleize "MyModel"
      "My Model"

  """
  def titleize(atom) when is_atom(atom) do
    atom
    |> Module.split
    |> List.last
    |> to_string
    |> titleize
  end
  def titleize(string) when is_binary(string) do
    string
    |> Inflex.underscore
    |> humanize
  end
  def titleize(%{__struct__: struct_name}) do
    titleize struct_name
  end

  @doc """
  Add a an or a in front of a word.

  ## Examples

      iex> Talon.Utils.articlize("hat")
      "a hat"

      iex> Talon.Utils.articlize("apple")
      "an apple"
  """
  def articlize(string) when is_binary(string) do
    if String.at(string, 0) in ~w(A a E e I i O o U u) do
      # gettext "an"
      "an"
    else
      # gettext "a"
      "a"
    end <> " " <> string
  end

  def parameterize(atom) when is_atom(atom),
    do: Atom.to_string(atom) |> parameterize
  def parameterize(str) when is_binary(str),
    do: Inflex.parameterize(str, "_")
    # do: str
  def parameterize(tuple) when is_tuple(tuple) do
    Tuple.to_list(tuple)
    |> Enum.map(&Kernel.to_string/1)
    |> Enum.join("_")
  end

  @doc false
  def action_name(conn) do
    Phoenix.Controller.action_name(conn)
  end


  @doc false
  def controller_name(name) when is_atom(name), do: extract_controller_name(name)
  def controller_name(%Plug.Conn{} = conn) do
    Phoenix.Controller.controller_module(conn)
    |> extract_controller_name
  end

  @doc false
  def resource_model(%Plug.Conn{} = conn) do
    conn.assigns.defn
    |> Map.get(:resource_model)
    |> base_name
  end

  def extract_controller_name(name) do
    base_name(name)
    |> String.split("Controller")
    |> List.first
  end

  @doc """
  URL helper to build assistant talon paths

  Examples:

      iex> Talon.Utils.talon_path
      "/talon"

      iex> Talon.Utils.talon_path(:page, [:dashboard])
      "/talon/page/dashboard"

      iex> Talon.Utils.talon_path(:select_theme, [1])
      "/talon/select_theme/1"
  """
  def talon_path do
    router_helpers().talon_path(endpoint(), :dashboard)
  end
  def talon_path(method, args \\ []) do
    apply(router_helpers(), :talon_path, [endpoint(), method | args])
  end

  @doc """
  URL helper for routes related to associations

  Examples:

      iex> Talon.Utils.talon_association_path(%TestTalon.Product{id: 1}, :tags)
      "/talon/products/1/tags"

      iex> Talon.Utils.talon_association_path(%TestTalon.Product{id: 1}, :tags, :update_positions)
      "/talon/products/1/tags/update_positions"
  """
  def talon_association_path(resource, assoc_name, method \\ nil, args \\ []) do
    resource_model = resource.__struct__
    resource_id = Talon.Schema.get_id(resource)
    apply(router_helpers(), :talon_association_path, [endpoint(), method || :index, resource_model.__schema__(:source), resource_id, assoc_name | args])
  end


  @doc """
  Returns a list of items from list1 that are not in list2
  """
  def not_in(list1, list2) do
    Enum.reduce(list1, [], &(if &1 in list2, do: &2, else: [&1 | &2]))
    |> Enum.reverse
  end

  @doc """
  Generate html for a link

  ## Syntax
      iex> Talon.Utils.link_to("click me", "/something", class: "link btn", style: "some styling")
      {:safe, "<a href='/something' class='link btn' style='some styling' >click me</a>"}
  """
  def link_to(name, path, opts \\[]) do
    attributes = case Keyword.get(opts, :remote) do
      true ->
        Keyword.delete(opts, :remote)
        |> Keyword.put(:"data-remote", "true")
      _ -> opts
    end
    |> Enum.reduce("", fn({k,v}, acc) -> acc <> "#{k}='#{v}' " end)

    "<a href='#{path}' #{attributes}>#{name}</a>"
    |> Phoenix.HTML.raw
  end


  @doc false
  def confirm_message, do: Messages.backend().are_you_sure_you_want_to_delete_this?()

  @doc false
  # def to_datetime(%Ecto.DateTime{} = dt) do
  #   {:ok, {date, {h,m,s,_ms}}} = Ecto.DateTime.dump dt
  #   {date, {h,m,s}}
  # end
  def to_datetime(%DateTime{} = dt) do
    DateTime.to_naive(dt)
    |> NaiveDateTime.to_erl
  end

  @doc false
  def format_time_difference({d, {h, m, s}}) do
    h = d * 24 + h
    zero_pad(h,2) <> ":" <> zero_pad(m,2) <> ":" <> zero_pad(s, 2)
  end

  @doc false
  def format_datetime({{y,m,d}, {h,min,s}}) do
    zero_pad(y, 4) <> "-" <> zero_pad(m, 2) <> "-" <> zero_pad(d, 2) <> " " <>
    zero_pad(h, 2) <> ":" <> zero_pad(min, 2) <> ":" <> zero_pad(s, 2)
  end

  @doc """
  Return the plural of a term.

  Returns a string give an atom or a string.
  """
  def pluralize(atom) when is_atom(atom) do
    Atom.to_string(atom) |> pluralize
  end
  def pluralize(singular) when is_binary(singular) do
    Inflex.pluralize(singular)
  end

  @doc """
  Return the plural of a term based on a passed count.

  If count is equal to 1, return the singular. Otherwise, return the
  plural.

  """
  def pluralize(atom, count) when is_atom(atom),
    do: pluralize(Atom.to_string(atom), count)
  def pluralize(name, 1), do: Inflex.singularize(name)
  def pluralize(name, _), do: Inflex.pluralize(name)

  @doc false
  def get_resource_label(%Plug.Conn{} = conn) do
    menu = conn.assigns.defn.menu
    Map.get menu, :label, resource_model(conn) |> titleize
  end

  @doc false
  def displayable_name_plural(conn) do
    Talon.Utils.get_resource_label(conn) |> Inflex.pluralize
  end
  def displayable_name_singular(conn) do
    Talon.Utils.get_resource_label(conn) |> Inflex.singularize
  end

  @doc false
  def authorized_action?(conn, action, resource_model) when is_atom(resource_model) do
    # fun = Application.get_env(:talon, :authorize)
    # if fun, do: fun.(conn, action, resource_model), else: true
    authorized_action? conn, action, resource_model.__struct__
  end
  def authorized_action?(conn, action, %{resource_model: resource_model}) do
    authorized_action?(conn, action, resource_model)
  end
  def authorized_action?(conn, action, resource) do
    Talon.Authorization.authorize_action(resource, conn, action)
  end
  #def authorized_action?(conn, action) do
  #  Talon.Authorization.authorize_action(conn.assigns[:defn], conn, action)
  #end

  @doc """
  General string to integer convertor.

  Takes either a string, a char list, or an integer

  ## Examples

      iex> Talon.to_integer(123)
      123

      iex> Talon.to_integer("123")
      123

      iex> Talon.to_integer([?1, ?2, ?3])
      123

      iex> Talon.to_integer("123A")
      123
  """
  @spec to_integer(integer | String.t) :: integer
  def to_integer(int) when is_integer(int), do: int

  def to_integer(list) when is_list(list) do
    list |> to_string |> to_integer
  end

  def to_integer(string) do
    case Integer.parse string do
      {int, _} -> int
      _ -> 0
    end
  end

  @doc false
  def use_authentication do
    false
  end

  def module_join(pre, post) do
    Module.concat nil, inspect(pre) <> inspect(post)
  end
end
