import QtQuick 2.15
import QtQuick.Window 2.15
import "file:///C:/Users/guanboyu/Documents/MedClaw/components"

Window {
    id: win
    width: 900
    height: 470
    visible: true
    color: "#EEF0F3"

    property int step: 0

    AskUserCard {
        id: card
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: 16
        width: 840
        visible: questions.length > 0
        questions: [
            {
                questionId: "m1",
                questionText: "多选：以下哪些处理你需要我一起做？",
                questionOptions: [
                    { label: "对比当前与既往影像，标记病灶变化" },
                    { label: "审阅分割结果并生成结构化报告" },
                    { label: "启动 AI 解读并生成含关键图注释的报告" },
                    { label: "挂载双视口(轴位 + 冠状位)后再测量" }
                ],
                questionMulti: true,
                questionAllowText: true
            },
            {
                questionId: "s1",
                questionText: "单选：报告里要不要包含测量数值？",
                questionOptions: [
                    { label: "包含 RECIST 1.1 长短径与变化率" },
                    { label: "只给结论，不列数值" }
                ],
                questionMulti: false,
                questionAllowText: true
            }
        ]
        onAnswered: function(id, answer) { console.log("ANSWER " + id + " => " + answer) }
        onSkipped: function(id) { console.log("SKIP " + id) }
    }

    Timer { interval: 700; running: true; onTriggered: win.step = 1 }

    function shot(name, done) {
        win.contentItem.grabToImage(function(res) {
            res.saveToFile("C:/Users/guanboyu/Documents/MedClaw/build/" + name)
            console.log("SHOT " + name)
            done()
        })
    }

    onStepChanged: {
        if (step === 1) {
            // 多选：勾两个
            card.toggleOption("对比当前与既往影像，标记病灶变化")
            card.toggleOption("启动 AI 解读并生成含关键图注释的报告")
            console.log("MULTI multi=" + card.activeMulti
                        + " selected=" + JSON.stringify(card.activeDraft.selected)
                        + " canSend=" + card.canSend)
            shot("askcard-multi.png", function() { win.step = 2 })
        } else if (step === 2) {
            // 切到单选页，确认序号样式没被改坏
            card.goNext()
            win.step = 3
        } else if (step === 3) {
            console.log("SINGLE multi=" + card.activeMulti
                        + " qid=" + card.activeId)
            shot("askcard-multi-single.png", function() { Qt.quit() })
        }
    }
}
