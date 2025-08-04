<?php

class __Mustache_e0039b5c1291cb4252322d4f7c5c85c5 extends Mustache_Template
{
    private $lambdaHelper;

    public function renderInternal(Mustache_Context $context, $indent = '')
    {
        $this->lambdaHelper = new Mustache_LambdaHelper($this->mustache, $context);
        $buffer = '';

        $buffer .= $indent . '<div class="course-content" id="courseformat-frontpage-main-topic">
';
        $value = $context->find('showsettings');
        $buffer .= $this->section8864e0a5883ef2eb50a24fb1adbc307d($context, $indent, $value);
        $buffer .= $indent . '    <div class="sitetopic">
';
        $buffer .= $indent . '        <ul class="topics section-list frontpage" data-for="course_sectionlist">
';
        $value = $context->find('sections');
        $buffer .= $this->sectionE906d22505faf08ef6e8ee3eb1fbd5a6($context, $indent, $value);
        $buffer .= $indent . '        </ul>
';
        $buffer .= $indent . '    </div>
';
        $buffer .= $indent . '</div>
';
        $value = $context->find('js');
        $buffer .= $this->section7720982c1c0c35c41fc1f43bace42598($context, $indent, $value);

        return $buffer;
    }

    private function section9a58bd3b46eea9f9784c07a37fbde3e5(Mustache_Context $context, $indent, $value)
    {
        $buffer = '';
    
        if (!is_string($value) && is_callable($value)) {
            $source = ' edit ';
            $result = (string) call_user_func($value, $source, $this->lambdaHelper);
            $buffer .= $result;
        } elseif (!empty($value)) {
            $values = $this->isIterable($value) ? $value : array($value);
            foreach ($values as $value) {
                $context->push($value);
                
                $buffer .= ' edit ';
                $context->pop();
            }
        }
    
        return $buffer;
    }

    private function sectionA77901af407ee1e447045c7d2b6ed22a(Mustache_Context $context, $indent, $value)
    {
        $buffer = '';
    
        if (!is_string($value) && is_callable($value)) {
            $source = ' i/settings, moodle ';
            $result = (string) call_user_func($value, $source, $this->lambdaHelper);
            $buffer .= $result;
        } elseif (!empty($value)) {
            $values = $this->isIterable($value) ? $value : array($value);
            foreach ($values as $value) {
                $context->push($value);
                
                $buffer .= ' i/settings, moodle ';
                $context->pop();
            }
        }
    
        return $buffer;
    }

    private function section8864e0a5883ef2eb50a24fb1adbc307d(Mustache_Context $context, $indent, $value)
    {
        $buffer = '';
    
        if (!is_string($value) && is_callable($value)) {
            $source = '
    <div class="mb-2">
        <a href="{{{settingsurl}}}" title="{{#str}} edit {{/str}}" aria-label="{{#str}} edit {{/str}}">
            {{#pix}} i/settings, moodle {{/pix}}
        </a>
    </div>
    ';
            $result = (string) call_user_func($value, $source, $this->lambdaHelper);
            $buffer .= $result;
        } elseif (!empty($value)) {
            $values = $this->isIterable($value) ? $value : array($value);
            foreach ($values as $value) {
                $context->push($value);
                
                $buffer .= $indent . '    <div class="mb-2">
';
                $buffer .= $indent . '        <a href="';
                $value = $this->resolveValue($context->find('settingsurl'), $context);
                $buffer .= ($value === null ? '' : $value);
                $buffer .= '" title="';
                $value = $context->find('str');
                $buffer .= $this->section9a58bd3b46eea9f9784c07a37fbde3e5($context, $indent, $value);
                $buffer .= '" aria-label="';
                $value = $context->find('str');
                $buffer .= $this->section9a58bd3b46eea9f9784c07a37fbde3e5($context, $indent, $value);
                $buffer .= '">
';
                $buffer .= $indent . '            ';
                $value = $context->find('pix');
                $buffer .= $this->sectionA77901af407ee1e447045c7d2b6ed22a($context, $indent, $value);
                $buffer .= '
';
                $buffer .= $indent . '        </a>
';
                $buffer .= $indent . '    </div>
';
                $context->pop();
            }
        }
    
        return $buffer;
    }

    private function sectionE906d22505faf08ef6e8ee3eb1fbd5a6(Mustache_Context $context, $indent, $value)
    {
        $buffer = '';
    
        if (!is_string($value) && is_callable($value)) {
            $source = '
                {{> core_courseformat/local/content/section }}
            ';
            $result = (string) call_user_func($value, $source, $this->lambdaHelper);
            $buffer .= $result;
        } elseif (!empty($value)) {
            $values = $this->isIterable($value) ? $value : array($value);
            foreach ($values as $value) {
                $context->push($value);
                
                if ($partial = $this->mustache->loadPartial('core_courseformat/local/content/section')) {
                    $buffer .= $partial->renderInternal($context, $indent . '                ');
                }
                $context->pop();
            }
        }
    
        return $buffer;
    }

    private function sectionFa2b04555a34f8237e7f406b34a24a0b(Mustache_Context $context, $indent, $value)
    {
        $buffer = '';
    
        if (!is_string($value) && is_callable($value)) {
            $source = '
require([\'core_courseformat/local/content\'], function(component) {
    component.init(\'#courseformat-frontpage-main-topic\', {});
});
';
            $result = (string) call_user_func($value, $source, $this->lambdaHelper);
            $buffer .= $result;
        } elseif (!empty($value)) {
            $values = $this->isIterable($value) ? $value : array($value);
            foreach ($values as $value) {
                $context->push($value);
                
                $buffer .= $indent . 'require([\'core_courseformat/local/content\'], function(component) {
';
                $buffer .= $indent . '    component.init(\'#courseformat-frontpage-main-topic\', {});
';
                $buffer .= $indent . '});
';
                $context->pop();
            }
        }
    
        return $buffer;
    }

    private function section7720982c1c0c35c41fc1f43bace42598(Mustache_Context $context, $indent, $value)
    {
        $buffer = '';
    
        if (!is_string($value) && is_callable($value)) {
            $source = '
{{! The home page should be as fast as possible, we only load the editor when needed.}}
{{#editing}}
require([\'core_courseformat/local/content\'], function(component) {
    component.init(\'#courseformat-frontpage-main-topic\', {});
});
{{/editing}}
';
            $result = (string) call_user_func($value, $source, $this->lambdaHelper);
            $buffer .= $result;
        } elseif (!empty($value)) {
            $values = $this->isIterable($value) ? $value : array($value);
            foreach ($values as $value) {
                $context->push($value);
                
                $value = $context->find('editing');
                $buffer .= $this->sectionFa2b04555a34f8237e7f406b34a24a0b($context, $indent, $value);
                $context->pop();
            }
        }
    
        return $buffer;
    }

}
