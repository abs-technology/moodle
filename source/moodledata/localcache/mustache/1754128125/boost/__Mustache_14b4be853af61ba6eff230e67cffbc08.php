<?php

class __Mustache_14b4be853af61ba6eff230e67cffbc08 extends Mustache_Template
{
    private $lambdaHelper;

    public function renderInternal(Mustache_Context $context, $indent = '')
    {
        $this->lambdaHelper = new Mustache_LambdaHelper($this->mustache, $context);
        $buffer = '';

        $value = $context->find('enabled');
        $buffer .= $this->section0c9db0f9478763b7d66b09772144bc1f($context, $indent, $value);

        return $buffer;
    }

    private function sectionB065c8dbc8d151f89d6bd5981ec3d0b6(Mustache_Context $context, $indent, $value)
    {
        $buffer = '';
    
        if (!is_string($value) && is_callable($value)) {
            $source = 'aria:footermessage, tool_moodlenet';
            $result = (string) call_user_func($value, $source, $this->lambdaHelper);
            $buffer .= $result;
        } elseif (!empty($value)) {
            $values = $this->isIterable($value) ? $value : array($value);
            foreach ($values as $value) {
                $context->push($value);
                
                $buffer .= 'aria:footermessage, tool_moodlenet';
                $context->pop();
            }
        }
    
        return $buffer;
    }

    private function section45c3b51742137cf49fc97bbde18ded97(Mustache_Context $context, $indent, $value)
    {
        $buffer = '';
    
        if (!is_string($value) && is_callable($value)) {
            $source = '
                    href="{{advanced}}"
                    target="_self"
                ';
            $result = (string) call_user_func($value, $source, $this->lambdaHelper);
            $buffer .= $result;
        } elseif (!empty($value)) {
            $values = $this->isIterable($value) ? $value : array($value);
            foreach ($values as $value) {
                $context->push($value);
                
                $buffer .= $indent . '                    href="';
                $value = $this->resolveValue($context->find('advanced'), $context);
                $buffer .= ($value === null ? '' : call_user_func($this->mustache->getEscape(), $value));
                $buffer .= '"
';
                $buffer .= $indent . '                    target="_self"
';
                $context->pop();
            }
        }
    
        return $buffer;
    }

    private function section79ea65bc258d7f8a1f6951c2b0c7a17a(Mustache_Context $context, $indent, $value)
    {
        $buffer = '';
    
        if (!is_string($value) && is_callable($value)) {
            $source = ' footermessage , tool_moodlenet';
            $result = (string) call_user_func($value, $source, $this->lambdaHelper);
            $buffer .= $result;
        } elseif (!empty($value)) {
            $values = $this->isIterable($value) ? $value : array($value);
            foreach ($values as $value) {
                $context->push($value);
                
                $buffer .= ' footermessage , tool_moodlenet';
                $context->pop();
            }
        }
    
        return $buffer;
    }

    private function section9952ff7f105b10351b2577ebf6dd3d2e(Mustache_Context $context, $indent, $value)
    {
        $buffer = '';
    
        if (!is_string($value) && is_callable($value)) {
            $source = ' MoodleNet, tool_moodlenet ';
            $result = (string) call_user_func($value, $source, $this->lambdaHelper);
            $buffer .= $result;
        } elseif (!empty($value)) {
            $values = $this->isIterable($value) ? $value : array($value);
            foreach ($values as $value) {
                $context->push($value);
                
                $buffer .= ' MoodleNet, tool_moodlenet ';
                $context->pop();
            }
        }
    
        return $buffer;
    }

    private function section0c9db0f9478763b7d66b09772144bc1f(Mustache_Context $context, $indent, $value)
    {
        $buffer = '';
    
        if (!is_string($value) && is_callable($value)) {
            $source = '
    <div class="w-100 d-flex px-2">
            <a aria-label="{{#str}}aria:footermessage, tool_moodlenet{{/str}}"
                class="d-inline my-auto me-1"
                {{#advanced}}
                    href="{{advanced}}"
                    target="_self"
                {{/advanced}}
                {{^advanced}}
                    href="#"
                    data-action="show-moodlenet"
                    data-courseid="{{courseID}}"
                    data-sectionnum="{{sectionnum}}"
                {{/advanced}}
            >
                {{#str}} footermessage , tool_moodlenet{{/str}}

                <span class="moodlenet-logo" aria-hidden="true">{{#pix}} MoodleNet, tool_moodlenet {{/pix}}</span>
            </a>
    </div>
';
            $result = (string) call_user_func($value, $source, $this->lambdaHelper);
            $buffer .= $result;
        } elseif (!empty($value)) {
            $values = $this->isIterable($value) ? $value : array($value);
            foreach ($values as $value) {
                $context->push($value);
                
                $buffer .= $indent . '    <div class="w-100 d-flex px-2">
';
                $buffer .= $indent . '            <a aria-label="';
                $value = $context->find('str');
                $buffer .= $this->sectionB065c8dbc8d151f89d6bd5981ec3d0b6($context, $indent, $value);
                $buffer .= '"
';
                $buffer .= $indent . '                class="d-inline my-auto me-1"
';
                $value = $context->find('advanced');
                $buffer .= $this->section45c3b51742137cf49fc97bbde18ded97($context, $indent, $value);
                $value = $context->find('advanced');
                if (empty($value)) {
                    
                    $buffer .= $indent . '                    href="#"
';
                    $buffer .= $indent . '                    data-action="show-moodlenet"
';
                    $buffer .= $indent . '                    data-courseid="';
                    $value = $this->resolveValue($context->find('courseID'), $context);
                    $buffer .= ($value === null ? '' : call_user_func($this->mustache->getEscape(), $value));
                    $buffer .= '"
';
                    $buffer .= $indent . '                    data-sectionnum="';
                    $value = $this->resolveValue($context->find('sectionnum'), $context);
                    $buffer .= ($value === null ? '' : call_user_func($this->mustache->getEscape(), $value));
                    $buffer .= '"
';
                }
                $buffer .= $indent . '            >
';
                $buffer .= $indent . '                ';
                $value = $context->find('str');
                $buffer .= $this->section79ea65bc258d7f8a1f6951c2b0c7a17a($context, $indent, $value);
                $buffer .= '
';
                $buffer .= $indent . '
';
                $buffer .= $indent . '                <span class="moodlenet-logo" aria-hidden="true">';
                $value = $context->find('pix');
                $buffer .= $this->section9952ff7f105b10351b2577ebf6dd3d2e($context, $indent, $value);
                $buffer .= '</span>
';
                $buffer .= $indent . '            </a>
';
                $buffer .= $indent . '    </div>
';
                $context->pop();
            }
        }
    
        return $buffer;
    }

}
