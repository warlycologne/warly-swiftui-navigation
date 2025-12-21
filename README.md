# warly-swiftui-navigation
A framework that provides a swiftui navigation with cross package support
It comes with a ton of features that are not supported out of the box by vanilla SwiftUI:
- Cross package navigation: You don't need to know all views you navigate to
- Requirements: Specify requirements that need to be fullfilled before navigating to a view. These requirements are observed and dismantle the view hierarchy when the requirement is no longer resolved
- Dynamic navigation action: Dynamically define if you want you view to pushed, presented or shown as bottom sheet
- Back navigation via reference: Navigate back to first or last reference without knowing the exact position. Across all presented navigation stacks
- Deeplinking: Adds simple deeplink support for app and universal links
- Includes: Include views into other views your package may not provide or are complex to create
- Destination actions: Send an action to a destination you're navigating to and execute it when it condition is met
- Focus: Detect when a view is the main focus of the app (e.g. not overlaid by a presented view)

It contains three sub packages:
- REWENavigation: Contains all types required to register navigation and use it
- REWENavigationUI: Contains all views to actually display the navigation
- REWENavigationMacro: The internal package providing macros for convenience

## Structure
To use SwiftUI navigation with this package there are tree main views:

### CoordinatedAppView
This is the base of the entire app. It sets basic environment values, handles urls coming from 
outside and inside the app and registers universal destinations that can be used accross the app 
(e.g. `AlertDestination` and `URLDestination`)

It expects the `CoordinatorStack`, `NavigationResolver`, a `URLHandler` and a @ViewBuilder content, that is the actual 
content of the app. You may provide any view here, but to actual leverage the package, it should be 
either `CoordinatedTabView` or `CoordinatedNavigationStack`.

### CoordinatedTabView
The CoordinatedTabView provides a tab view with each tab having a `CoordinatedNavigationStack` as 
its content. It also registeres the `TabDestination` to navigate to a tab from anywhere.

### CoordinatedNavigationStack
The heart of the package. In this view all navigation is handled, from simple push/pop to sheets, 
bottom sheets, fullscreen views and alerts. Each CoordinatedNavigationStack is backed by a 
coordinator. In contrast to our previous coordinator pattern, the coordinator here is bound to one 
CoordinatedNavigationStack, every time a new CoordinatedNavigationStack is presented, a new 
coordinator is created.

### Coordinator
The coordinator holds all data relevant for navigation. The coordinator expects the root, an 
optional parent and the `NavigationResolver` You typically only create coordinators yourself for 
the root of your navigation, be it the `CoordinatedTabView` or for any `CoordinatedNavigationStack`.
It uses the `NavigationResolver` as its delegate to retrieve views and resolve requirements.

### Navigator
The navigator is protocol conformed to by the coordinator and provides navigation related methods.
When you interact with the navigation system, you will use that protocol.

### Destination
A destination is the definition of where you want to navigate to. There are basically two types of
destinations:

- `Destination`: 
A destination you want to navigate to, but don't know how. These kind of destinations
are required to mapped to either another `Destination` or final `ViewDestination`

- `ViewDestination`: 
A destination that can be displayed. It defines which requirements need to be met
before navigation, how it wants to displayed, which references it has and which data it requires.

If you use an `enum` to group multiple destinations, make sure to use the `#NavigateTo(_:)` macro on 
the navigator in order to easily navigate to your destination:

```
extension Navigator {
    #NavigateTo(YourDestination.self)
}
```

## Set up
### NavigationResolver
To register your different destinations you first create the `NavigationResolver`. It has all the 
methods to register requirements, destination mappers, deeplink handlers and view factories for
destinations. It requires a `StateDestinationViewFactory` that gives you the option to decorate navigation
stacks, content views and bottom sheets to your needs and provide state views for placeholders and 
unresolvable destinations.

Optionally you can provide a `DeeplinkConfiguration` to configure your app scheme and how to detect
universal urls you like to handle. 

### IncludeResolver
Additionally to the `NavigationResolver` which is responsable for destinations you navigate to, the 
`IncludeResolver` gives you all the methods to register destinations that are meant to be included
into views. 

### ViewFactory
For each `ViewDestination` you need to register a `ViewFactory`. The view factory is called to 
provide a view and optional decoration for a navigation stack. The method 
`view(for:navigator:context:)` provides the navigator that you use to navigate and a context struct
that holds all relavant data to set up the view. 
**Attention** When you create your view with a view model, make sure to `context.cache()` it!

The `decorateNavigationStack(_:for:navigator:context:)` provides the option to decorate a navigation
stack when the requested destination is at the beginning of one. You may use this to add elements
that should stick with the navigation stack (e.g. basket button or order modify cancel button).
**Attention** Refrain from creating any view models in this method. Instead create the view model in the 
`view(for:navigator:context:)` method and use the `context.cache()` method there
and `context.extract(_:)` in here:

```
struct DestinationViewFactory: ViewFactory {
    func view(
        for destination: Destination, 
        navigator: any Navigator, 
        context: inout ViewContext
    ) -> some View {
        MyView(viewModel: context.cache(MyViewModel()))
    }
    
    func decorateNavigationStack(
        _ navigationStack: AnyView, 
        for destination: Destination, 
        navigator: any Navigator, 
        context: ViewContext
    ) -> some View {
        navigationStack
            .customModifier(viewModel: context.extract(MyViewModel.self))
    }
}
```

## Using
### Inside a view
When inside the app you get various properties you can work with:
- `@Environment(\.isViewFocused)` Whether the view is currently the focus of the screen. This differs from 
`onAppear`/`onDisappear` where they are only called when screen appears for the first time
or disappears completely from the screen. Additionally you can use `onFocus()` and `onBlur()`
to handle a change independently.
- `@Environment(\.presentation)` Contains the information how the current view is being presented
or `nil` if it is pushed onto a navigation stack
- `@Environment(\.isModal)` Whether the current view (when presented) is being modal
- `@Environment(\.include)` To include other views you may not know or are complex to create

## Customising
### StateDestinationViewFactory
When creating a new `NavigationResolver` you can provide a view factory for universal states of the 
navigation system. Here you provide the views for error states (view not found, placeholders)
and have the ability to decorate views (navigation stack, navigation stack content, bottom sheets)
