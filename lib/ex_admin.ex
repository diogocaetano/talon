defmodule ExAdmin do
  @moduledoc """


  First, some termonolgy:

  * schema - The name of a give schema. .i.e. TestExAdmin.Simple
  * admin_resource - the admin module for a given schema. .i.e. TestExAdmin.ExAdmin.Simple

  ## resource_map

      iex> TestExAdmin.Admin.resource_map()["simples"]
      TestExAdmin.ExAdmin.Simple

      iex> TestExAdmin.Admin.resources() |> Enum.any?(& &1 == TestExAdmin.ExAdmin.Simple)
      true

      iex> TestExAdmin.Admin.resource_names()|> Enum.any?(& &1 == "simples")
      true

      iex> TestExAdmin.Admin.schema("simples")
      TestExAdmin.Simple

      iex> TestExAdmin.Admin.schema_names() |> Enum.any?(& &1 == "Simple")
      true

      iex> TestExAdmin.Admin.admin_resource("simples")
      TestExAdmin.ExAdmin.Simple

      iex> TestExAdmin.Admin.admin_resource(TestExAdmin.Simple)
      TestExAdmin.ExAdmin.Simple

      iex> TestExAdmin.Admin.admin_resource(%TestExAdmin.Simple{})
      TestExAdmin.ExAdmin.Simple

      iex> TestExAdmin.Admin.controller_action("simples")
      {TestExAdmin.Simple, :simples, "admin_lte"}

      iex> TestExAdmin.Admin.base()
      TestExAdmin

      iex> TestExAdmin.Admin.template_path_name("simples")
      "simple"
  """

  defmacro __using__(opts) do
    otp_app = opts[:otp_app]
    unless otp_app do
      raise "Must provide :otp_app option"
    end

    repo = opts[:repo]

    quote location: :keep do
      @__resources__  Application.get_env(:ex_admin, :resources, [])

      @__resource_map__  for mod <- @__resources__, into: %{},
        do: {Module.split(mod) |> List.last() |> to_string |> Inflex.underscore |> Inflex.Pluralize.pluralize, mod}

      @__view_path_names__ for {plural, _} <- @__resource_map__, into: %{}, do: {plural, Inflex.singularize(plural)}

      # @__resource_to_admin__ for resource <- @__resources__, do: {resource.schema(), resource}

      @__base__ Module.split(__MODULE__) |> hd |> Module.concat(nil)

      @__repo__ unquote(repo) || Module.concat(@__base__, Repo)

      @spec base() :: atom
      def base, do: @__base__

      @spec repo() :: atom
      def repo, do: @__repo__

      def resource_map, do: @__resource_map__

      def resources, do: @__resources__

      def resource_names, do: @__resource_map__ |> Map.keys

      def schema(resource_name) do
        admin_resource(resource_name).schema()
      end

      def schema_names do
        resource_names()
        |> Enum.map(fn name ->
          name |> schema |> Module.split |> List.last
        end)
      end

      def admin_resource(resource_name) when is_binary(resource_name) do
        @__resource_map__[resource_name]
      end
      def admin_resource(struct) when is_atom(struct) do
        with {_, resource} <- Enum.find(@__resources__, &(struct == &1.schema())), do: resource
      end
      def admin_resource(resource) when is_map(resource) do
        admin_resource(resource.__struct__)
      end

      def resource_schema(resource_name) when is_binary(resource_name) do
        {String.to_atom(resource_name), admin_resource(resource_name)}
      end

      def controller_action(resource_name) do
        {resource_name, admin_resource} = resource_schema(resource_name)
        schema = admin_resource.schema()
        {schema, resource_name, Application.get_env(:ex_admin, :theme)}
      end

      def template_path_name(resource_name) do
        @__view_path_names__[resource_name]
      end

      defoverridable [
          base: 0, repo: 0, resource_map: 0, schema: 1, schema_names: 0, admin_resource: 1,
          resource_schema: 1, controller_action: 1, template_path_name: 1
        ]
    end
  end

  @doc """
  Return the app's base module.

  ## Examples

      iex> ExAdmin.app_module(TestExAdmin.Admin)
      TestExAdmin
  """
  @spec app_module(atom) :: atom
  def app_module(admin) do
    admin.base()
  end
end
