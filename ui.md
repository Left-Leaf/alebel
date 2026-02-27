# AI协助构建UI组件公约

1. 所有Widget遵循自适应原则，非必要条件下，不使用固定尺寸。
2. 减少使用Container组件，尽量使用DecoratedBox，Padding，Align， SizedBox，ColorBox等组件。
3. 尽量使用StatelessWidget，避免使用StatefulWidget。
4. 尽量避免使用到InheritedWidget的功能。
5. StatefulWidget通过实现didUpdateWidget方法，来实现Widget的更新。
6. 如果项目有统一的颜色定义类或文件，则尽量使用该类或文件中的颜色定义。
7. 如果项目有统一的资源路径定义类或文件，则尽量使用该类或文件中的路径定义。
8. 如果项目插件有GetX，则尽量使用GetX的组件实现状态管理。页面结构分为三段式：View（UI展示），Logic（逻辑处理），State（状态管理）。
9. 使用Listenable时，注意它的生命周期管理，避免内存泄漏。
10. 使用Stream时，注意它的生命周期管理，避免内存泄漏。
11. 使用Row和Column进行横向和纵向布局。Spacer用于在布局中添加空白空间。Expanded和Flexible用于在布局中为子Widget添加弹性空间。SizedBox用于设置子Widget的尺寸。
12. 使用SafeArea组件来处理刘海屏、圆角等设备差异。
13. 如果项目有统一的组件文件夹，创建一个新的组件时，尽量在组件文件夹中创建。如果组件文件夹有项目专门的图片展示，文本展示，文本编辑组件，则尽量使用该组件。
14. 涉及到复杂组件时，可以尝试使用RenderObjectWidget来实现。