library backdrop;

import 'dart:async';

import 'package:flutter/material.dart';

/// This class is an InheritedWidget that exposes state of [BackdropScaffold]
/// [_BackdropScaffoldState] to be accessed from anywhere below the widget tree.
///
/// It can be used to explicitly call backdrop functionality like fling,
/// showBackLayer, showFrontLayer, etc.
///
/// Example:
/// ```dart
/// Backdrop.of(context).fling();
/// ```
class Backdrop extends InheritedWidget {
  /// Holds the state of this widget.
  final _BackdropScaffoldState data;

  /// Creates a [Backdrop] instance.
  Backdrop({Key key, @required this.data, @required Widget child})
      : super(key: key, child: child);

  /// Provides access to the state from everywhere in the widget tree.
  static _BackdropScaffoldState of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<Backdrop>().data;

  @override
  bool updateShouldNotify(Backdrop old) => true;
}

/// Implements the basic functionality of backdrop.
///
/// This class internally uses [Scaffold]. It allows to set a back layer and a
/// front layer and manage the switching between the two. The implementation is
/// inspired by the
/// [material backdrop component](https://material.io/components/backdrop/).
///
/// Usage example:
/// ```dart
/// Widget build(BuildContext context) {
///   return MaterialApp(
///     title: 'Backdrop Demo',
///     home: BackdropScaffold(
///       title: Text("Backdrop Example"),
///       backLayer: Center(
///         child: Text("Back Layer"),
///       ),
///       frontLayer: Center(
///         child: Text("Front Layer"),
///       ),
///       iconPosition: BackdropIconPosition.leading,
///       actions: <Widget>[
///         BackdropToggleButton(
///           icon: AnimatedIcons.list_view,
///         ),
///       ],
///     ),
///   );
/// }
/// ```
///
/// See also:
///  * [Scaffold], which is the plain scaffold used in material apps.
class BackdropScaffold extends StatefulWidget {
  /// Can be used to customize the behaviour of the backdrop animation.
  final AnimationController controller;

  /// The widget assigned to the [Scaffold]'s [AppBar.title].
  final Widget title;

  /// Content that should be displayed on the back layer.
  final Widget backLayer;

  /// The widget that is shown on the front layer .
  final Widget frontLayer;

  /// Actions passed to [AppBar.actions].
  final List<Widget> actions;

  /// Defines the height of the front layer when it is in the opened state.
  ///
  /// This height value is only applied, if [stickyFrontLayer]
  /// is set to `false` or if [stickyFrontLayer] is set to `true` and the back
  /// layer's height is less than
  /// [BoxConstraints.biggest.height]-[headerHeight].
  ///
  /// [headerHeight] is interpreted as the height of the front layer's visible
  /// part, when being opened. The back layer's height corresponds to
  /// [BoxConstraints.biggest.height]-[headerHeight].
  ///
  /// Defaults to 32.0.
  final double headerHeight;

  /// Defines the [BorderRadius] applied to the front layer.
  ///
  /// Defaults to
  /// ```dart
  /// const BorderRadius.only(
  ///     topLeft: Radius.circular(16.0),
  ///     topRight: Radius.circular(16.0),
  /// )
  /// ```
  final BorderRadius frontLayerBorderRadius;

  /// The position of the icon button that toggles the backdrop functionality.
  ///
  /// Defaults to [BackdropIconPosition.leading].
  final BackdropIconPosition iconPosition;

  /// A flag indicating whether the front layer should stick to the height of
  /// the back layer when being opened.
  ///
  /// Defaults to `false`.
  final bool stickyFrontLayer;

  /// The animation curve passed to [Tween.animate]() when triggering
  /// the backdrop animation.
  ///
  /// Defaults to [Curves.linear].
  final Curve animationCurve;

  /// Passed to the [Scaffold] underlying [BackdropScaffold].
  /// See [Scaffold.resizeToAvoidBottomInset].
  ///
  /// Defaults to `true`.
  final bool resizeToAvoidBottomInset;

  /// Creates a backdrop scaffold to be used as a material widget.
  BackdropScaffold({
    this.controller,
    this.title,
    this.backLayer,
    this.frontLayer,
    this.actions = const <Widget>[],
    this.headerHeight = 32.0,
    this.frontLayerBorderRadius = const BorderRadius.only(
      topLeft: Radius.circular(16.0),
      topRight: Radius.circular(16.0),
    ),
    this.iconPosition = BackdropIconPosition.leading,
    this.stickyFrontLayer = false,
    this.animationCurve = Curves.linear,
    this.resizeToAvoidBottomInset = true,
  });

  @override
  _BackdropScaffoldState createState() => _BackdropScaffoldState();
}

class _BackdropScaffoldState extends State<BackdropScaffold>
    with SingleTickerProviderStateMixin {
  bool _shouldDisposeController = false;
  AnimationController _controller;
  final scaffoldKey = GlobalKey<ScaffoldState>();
  GlobalKey _backLayerKey = GlobalKey();
  double _backPanelHeight = 0;

  AnimationController get controller => _controller;

  @override
  void initState() {
    super.initState();
    if (widget.controller == null) {
      _shouldDisposeController = true;
      _controller = AnimationController(
          vsync: this, duration: Duration(milliseconds: 100), value: 1.0);
    } else {
      _controller = widget.controller;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      setState(() {
        _backPanelHeight = _getBackPanelHeight();
      });
    });
  }

  @override
  void dispose() {
    super.dispose();
    if (_shouldDisposeController) _controller.dispose();
  }

  bool get isTopPanelVisible =>
      controller.status == AnimationStatus.completed ||
      controller.status == AnimationStatus.forward;

  bool get isBackPanelVisible {
    final AnimationStatus status = controller.status;
    return status == AnimationStatus.dismissed ||
        status == AnimationStatus.reverse;
  }

  void fling() => controller.fling(velocity: isTopPanelVisible ? -1.0 : 1.0);

  void showBackLayer() {
    if (isTopPanelVisible) controller.fling(velocity: -1.0);
  }

  void showFrontLayer() {
    if (isBackPanelVisible) controller.fling(velocity: 1.0);
  }

  double _getBackPanelHeight() =>
      ((_backLayerKey.currentContext?.findRenderObject() as RenderBox)
          ?.size
          ?.height) ??
      0.0;

  Animation<RelativeRect> getPanelAnimation(
      BuildContext context, BoxConstraints constraints) {
    var backPanelHeight, frontPanelHeight;

    if (widget.stickyFrontLayer &&
        _backPanelHeight < constraints.biggest.height - widget.headerHeight) {
      // height is adapted to the height of the back panel
      backPanelHeight = _backPanelHeight;
      frontPanelHeight = -_backPanelHeight;
    } else {
      // height is set to fixed value defined in widget.headerHeight
      final height = constraints.biggest.height;
      backPanelHeight = height - widget.headerHeight;
      frontPanelHeight = -backPanelHeight;
    }
    return RelativeRectTween(
      begin: RelativeRect.fromLTRB(0.0, backPanelHeight, 0.0, frontPanelHeight),
      end: RelativeRect.fromLTRB(0.0, 0.0, 0.0, 0.0),
    ).animate(CurvedAnimation(
      parent: controller,
      curve: widget.animationCurve,
    ));
  }

  Widget _buildInactiveLayer(BuildContext context) {
    return Offstage(
      offstage: isTopPanelVisible,
      child: GestureDetector(
        onTap: () => fling(),
        behavior: HitTestBehavior.opaque,
        child: SizedBox.expand(
          child: Container(
            decoration: BoxDecoration(
              borderRadius: widget.frontLayerBorderRadius,
              color: Colors.grey.shade200.withOpacity(0.7),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBackPanel() {
    return FocusScope(
      canRequestFocus: isBackPanelVisible,
      child: Material(
        color: Theme.of(context).primaryColor,
        child: Column(
          children: <Widget>[
            Flexible(
                key: _backLayerKey, child: widget.backLayer ?? Container()),
          ],
        ),
      ),
    );
  }

  Widget _buildFrontPanel(BuildContext context) {
    return Material(
      elevation: 12.0,
      borderRadius: widget.frontLayerBorderRadius,
      child: Stack(
        children: <Widget>[
          widget.frontLayer,
          _buildInactiveLayer(context),
        ],
      ),
    );
  }

  Future<bool> _willPopCallback(BuildContext context) async {
    if (isBackPanelVisible) {
      showFrontLayer();
      return null;
    }
    return true;
  }

  Widget _buildBody(BuildContext context) {
    return WillPopScope(
      onWillPop: () => _willPopCallback(context),
      child: Scaffold(
        key: scaffoldKey,
        appBar: AppBar(
          title: widget.title,
          actions: widget.iconPosition == BackdropIconPosition.action
              ? <Widget>[BackdropToggleButton()] + widget.actions
              : widget.actions,
          elevation: 0.0,
          leading: widget.iconPosition == BackdropIconPosition.leading
              ? BackdropToggleButton()
              : null,
        ),
        body: LayoutBuilder(
          builder: (context, constraints) {
            return Container(
              child: Stack(
                children: <Widget>[
                  _buildBackPanel(),
                  PositionedTransition(
                    rect: getPanelAnimation(context, constraints),
                    child: _buildFrontPanel(context),
                  ),
                ],
              ),
            );
          },
        ),
        resizeToAvoidBottomInset: widget.resizeToAvoidBottomInset,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Backdrop(
      data: this,
      child: Builder(
        builder: (context) => _buildBody(context),
      ),
    );
  }
}

/// An animated button that can be used to trigger the backdrop functionality of
/// [BackdropScaffold].
///
/// This button is used directly within [BackdropScaffold]. Its position can be
/// specified using [BackdropIconPosition].
/// This button can also be passed to the [AppBar.actions] of an [AppBar].
///
/// When being pressed, [BackdropToggleButton] looks for a [Backdrop] instance
/// above it in the widget tree and toggles its opening/closing.
///
/// Example:
/// ```dart
/// Widget build(BuildContext context) {
///   return MaterialApp(
///     title: 'Backdrop Demo',
///     home: BackdropScaffold(
///       ...
///       actions: <Widget>[
///         BackdropToggleButton(
///           icon: AnimatedIcons.list_view,
///         ),
///       ],
///     ),
///   );
/// }
/// ```
class BackdropToggleButton extends StatelessWidget {
  /// Animated icon that is used for the contained [AnimatedIcon].
  ///
  /// Defaults to [AnimatedIcons.close_menu].
  final AnimatedIconData icon;

  /// Creates an instance of [BackdropToggleButton].
  const BackdropToggleButton({
    this.icon = AnimatedIcons.close_menu,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: AnimatedIcon(
        icon: icon,
        progress: Backdrop.of(context).controller.view,
      ),
      onPressed: () => Backdrop.of(context).fling(),
    );
  }
}

/// This enum is used to specify where [BackdropToggleButton] should appear
/// within [AppBar].
enum BackdropIconPosition {
  /// Indicates that [BackdropToggleButton] should not appear at all.
  none,

  /// Indicates that [BackdropToggleButton] should appear at the start of
  /// [AppBar].
  leading,

  /// Indicates that [BackdropToggleButton] should appear as an action within
  /// [AppBar.actions].
  action
}

/// Implements the back layer to be used for navigation.
///
/// This class can be used as a back layer for [BackdropScaffold]. It enables to
/// use the back layer as a navigation list, similar to a [Drawer].
///
/// Usage example:
/// ```dart
/// int _currentIndex = 0;
/// final List<Widget> _frontLayers = [Widget1(), Widget2()];
///
/// @override
/// Widget build(BuildContext context) {
///   return MaterialApp(
///     title: 'Backdrop Demo',
///     home: BackdropScaffold(
///       title: Text("Backdrop Navigation Example"),
///       iconPosition: BackdropIconPosition.leading,
///       actions: <Widget>[
///         BackdropToggleButton(
///           icon: AnimatedIcons.list_view,
///         ),
///       ],
///       stickyFrontLayer: true,
///       frontLayer: _frontLayers[_currentIndex],
///       backLayer: BackdropNavigationBackLayer(
///         items: [
///           ListTile(title: Text("Widget 1")),
///           ListTile(title: Text("Widget 2")),
///         ],
///         onTap: (int position) => {setState(() => _currentIndex = position)},
///       ),
///     ),
///   );
/// }
/// ```
class BackdropNavigationBackLayer extends StatelessWidget {
  /// The items to be inserted into the underlying [ListView] of the
  /// [BackdropNavigationBackLayer].
  final List<Widget> items;

  /// Callback that is called whenever a list item is tapped by the user.
  final ValueChanged<int> onTap;

  /// Customizable separator used with [ListView.separated].
  final Widget separator;

  /// Creates an instance of [BackdropNavigationBackLayer] to be used with
  /// [BackdropScaffold].
  ///
  /// The argument [items] is required and must not be `null` and not empty.
  BackdropNavigationBackLayer({
    Key key,
    @required this.items,
    this.onTap,
    this.separator,
  })  : assert(items != null),
        assert(items.isNotEmpty),
        super(key: key);

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      shrinkWrap: true,
      itemCount: items.length,
      itemBuilder: (context, position) => InkWell(
        child: items[position],
        onTap: () {
          // fling backdrop
          Backdrop.of(context).fling();

          // call onTap function and pass new selected index
          onTap?.call(position);
        },
      ),
      separatorBuilder: (builder, position) => separator ?? Container(),
    );
  }
}
